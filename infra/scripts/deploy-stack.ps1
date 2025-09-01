# infra/scripts/deploy-stack.ps1 - Deploy or remove GitOps software stack to/from existing HostK8s cluster
. "$PSScriptRoot\common.ps1"

# Load environment configuration
Load-Environment

function Show-Usage {
    Write-Host "Usage: deploy-stack.ps1 [down] [STACK_NAME]"
    Write-Host ""
    Write-Host "Deploy or remove a software stack to/from the cluster."
    Write-Host ""
    Write-Host "Arguments:"
    Write-Host "  down        Remove mode - removes the stack"
    Write-Host "  STACK_NAME  Stack to deploy/remove"
    Write-Host ""
    Write-Host "Environment Variables:"
    Write-Host "  SOFTWARE_STACK  Stack name (alternative to STACK_NAME argument)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  `$env:SOFTWARE_STACK='sample'; deploy-stack.ps1        # Deploy sample stack"
    Write-Host "  deploy-stack.ps1 down sample                         # Remove sample stack"
    Write-Host "  deploy-stack.ps1 down extension/my-stack             # Remove extension stack"
}

# Function to remove a software stack
function Remove-Stack {
    param([string]$StackName)

    # Check if cluster exists
    $clusters = kind get clusters 2>$null
    if (-not ($clusters -contains $env:CLUSTER_NAME)) {
        Log-Error "Cluster '$($env:CLUSTER_NAME)' does not exist"
        exit 1
    }

    # Set up kubeconfig if needed
    if (-not (Test-Path $env:KUBECONFIG_PATH)) {
        Log-Info "Setting up kubeconfig..."
        $kubeconfigDir = Split-Path $env:KUBECONFIG_PATH -Parent
        New-Item -ItemType Directory -Path $kubeconfigDir -Force | Out-Null
        kind export kubeconfig --name $env:CLUSTER_NAME --kubeconfig $env:KUBECONFIG_PATH
    }

    # Check if cluster is ready
    try {
        kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" cluster-info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Cluster '$($env:CLUSTER_NAME)' is not ready"
            exit 1
        }
    } catch {
        Log-Error "Cluster '$($env:CLUSTER_NAME)' is not ready"
        exit 1
    }

    # First check if the stack is actually deployed
    Log-Info "Checking if stack '$StackName' is deployed..."

    $bootstrapExists = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" get kustomization bootstrap-$StackName -n flux-system --no-headers 2>$null

    # Check if bootstrap kustomization exists
    if (-not $bootstrapExists) {
        Log-Info "Stack '$StackName' is not currently deployed"
        Log-Info "Nothing to remove - stack is already clean"
        return
    }

    Log-Info "Stack '$StackName' found - proceeding with removal"

    # Get all kustomizations BEFORE deleting bootstrap to know what was created by this stack
    # This captures all kustomizations that the stack created (components, apps, etc.)
    $allKustomizationsBefore = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" get kustomizations -n flux-system --no-headers -o custom-columns="NAME:.metadata.name" 2>$null

    # Remove the bootstrap kustomization first
    Log-Info "Removing bootstrap kustomization: bootstrap-$StackName"
    try {
        kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" delete kustomization bootstrap-$StackName -n flux-system 2>$null
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Bootstrap kustomization deleted"
        }
    } catch {
        Log-Warn "Failed to delete bootstrap kustomization"
    }

    # Wait a moment for Flux to start garbage collection
    Start-Sleep -Seconds 2

    # Get remaining kustomizations after bootstrap deletion
    $allKustomizationsAfter = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" get kustomizations -n flux-system --no-headers -o custom-columns="NAME:.metadata.name" 2>$null

    # Find kustomizations that still exist (these were created by the stack but not garbage collected yet)
    # We'll delete any kustomization that starts with "app-${StackName}" or "component-"
    if ($allKustomizationsAfter) {
        Log-Info "Cleaning up remaining stack kustomizations..."
        $allKustomizationsAfter -split "`n" | ForEach-Object {
            $kustomizationName = $_.Trim()
            if ($kustomizationName) {
                # Delete app-specific kustomizations for this stack
                if ($kustomizationName -like "app-$StackName*") {
                    Log-Info "Removing application kustomization: $kustomizationName"
                    kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" delete kustomization "$kustomizationName" -n flux-system 2>$null
                }
                # Delete component kustomizations (these are typically shared but created by stacks)
                elseif ($kustomizationName -like "component-*") {
                    Log-Info "Removing component kustomization: $kustomizationName"
                    kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" delete kustomization "$kustomizationName" -n flux-system 2>$null
                }
            }
        }
    }

    # Clean up the GitRepository (it was created by the stack, not by Flux installation)
    # Now using unique names per stack: flux-system-${StackName}
    if ($StackName -match "^extension/") {
        Log-Info "Cleaning up extension GitRepository..."
        try {
            kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" delete gitrepository extension-stack-system -n flux-system 2>$null
        } catch {
            Log-Debug "Extension GitRepository already cleaned up"
        }
    } else {
        Log-Info "Cleaning up GitRepository: flux-system-$StackName"
        try {
            kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" delete gitrepository "flux-system-$StackName" -n flux-system 2>$null
        } catch {
            Log-Debug "GitRepository already cleaned up"
        }
    }

    Log-Success "Software stack '$StackName' removal initiated"
    Log-Info "Flux will complete the cleanup automatically (may take 1-2 minutes)"
    Log-Info "Monitor with: kubectl get all --all-namespaces | Select-String -NotMatch flux-system"
}

# Function to apply stack YAML files with template substitution support
function Apply-StackYaml {
    param(
        [string]$YamlFile,
        [string]$Description
    )

    if (Test-Path $YamlFile) {
        Log-Info $Description
        # Check if this is an extension stack that needs template processing
        if ($YamlFile -match "extension/") {
            Log-Debug "Processing template variables for extension stack"
            # For now, template processing would need envsubst equivalent - applying directly
            $output = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" apply -f $YamlFile 2>&1
            Write-Host $output
            if ($LASTEXITCODE -ne 0) {
                Log-Warn "Failed to apply $Description"
            }
        } else {
            $output = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" apply -f $YamlFile 2>&1
            Write-Host $output
            if ($LASTEXITCODE -ne 0) {
                Log-Warn "Failed to apply $Description"
            }
        }
    } else {
        Log-Error "Stack configuration not found: $YamlFile"
        Log-Error "Available stacks:"
        $stacks = Get-ChildItem "software/stacks" -Directory -ErrorAction SilentlyContinue
        if ($stacks) {
            $stacks | ForEach-Object { Log-Info "  $($_.Name)" }
        } else {
            Log-Info "  No stacks found"
        }
        exit 1
    }
}

function Main {
    param([string[]]$Arguments)

    # Handle command line arguments
    $Operation = ""
    $StackName = ""

    if ($Arguments.Count -eq 0) {
        Show-Usage
        return 1
    }

    if ($Arguments[0] -eq "down") {
        $Operation = "down"
        if ($Arguments.Count -gt 1) {
            $StackName = $Arguments[1]
        } else {
            $StackName = $env:SOFTWARE_STACK
        }
        if (-not $StackName) {
            Log-Error "Stack name must be specified for down operation"
            Show-Usage
            return 1
        }
    } else {
        # Legacy mode - first argument is the stack name
        $StackName = $Arguments[0]
        $Operation = "deploy"
    }

    # Validate required parameters
    if (-not $StackName) {
        if ($env:SOFTWARE_STACK) {
            $StackName = $env:SOFTWARE_STACK
        } else {
            Log-Error "SOFTWARE_STACK must be specified"
            Show-Usage
            return 1
        }
    }

    # Execute the requested operation
    if ($Operation -eq "down") {
        Log-Start "Removing software stack '$StackName'..."
        Remove-Stack -StackName $StackName
        return 0
    } else {
        Log-Start "Deploying software stack '$StackName'..."
    }

    # Check if cluster exists
    $clusters = kind get clusters 2>$null
    if (-not ($clusters -contains $env:CLUSTER_NAME)) {
        Log-Error "Cluster '$($env:CLUSTER_NAME)' does not exist"
        Log-Error "Create cluster first: make start"
        return 1
    }

    # Set up kubeconfig if needed
    if (-not (Test-Path $env:KUBECONFIG_PATH)) {
        Log-Info "Setting up kubeconfig for existing cluster..."
        $kubeconfigDir = Split-Path $env:KUBECONFIG_PATH -Parent
        New-Item -ItemType Directory -Path $kubeconfigDir -Force | Out-Null
        kind export kubeconfig --name $env:CLUSTER_NAME --kubeconfig $env:KUBECONFIG_PATH
    }

    # Check if cluster is ready
    try {
        kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" cluster-info | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Cluster '$($env:CLUSTER_NAME)' is not ready"
            return 1
        }
    } catch {
        Log-Error "Cluster '$($env:CLUSTER_NAME)' is not ready"
        return 1
    }

    # Check if Flux is installed, install if not
    try {
        kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" get namespace flux-system | Out-Null
        $fluxNamespaceExists = ($LASTEXITCODE -eq 0)
    } catch {
        $fluxNamespaceExists = $false
    }

    if (-not $fluxNamespaceExists) {
        Log-Info "Flux not found. Installing Flux first..."
        $env:FLUX_ENABLED = "true"
        & "$PSScriptRoot\setup-flux.ps1"
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to install Flux"
            return 1
        }
    } else {
        # Check if Flux installation is complete
        try {
            $fluxPods = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" get pods -n flux-system -l app.kubernetes.io/part-of=flux --no-headers 2>$null
            $runningPods = $fluxPods | Where-Object { $_ -match "Running" }
            if (-not $runningPods) {
                Log-Info "Flux installation incomplete. Completing installation..."
                $env:FLUX_ENABLED = "true"
                & "$PSScriptRoot\setup-flux.ps1"
                if ($LASTEXITCODE -ne 0) {
                    Log-Error "Failed to complete Flux installation"
                    return 1
                }
            } else {
                Log-Info "Flux is already installed and running"
            }
        } catch {
            Log-Info "Flux installation incomplete. Completing installation..."
            $env:FLUX_ENABLED = "true"
            & "$PSScriptRoot\setup-flux.ps1"
            if ($LASTEXITCODE -ne 0) {
                Log-Error "Failed to complete Flux installation"
                return 1
            }
        }
    }

    # Deploy the software stack
    Log-Info "Deploying software stack '$StackName'..."

    # Set GitOps repository defaults for stack deployment
    if (-not $env:GITOPS_REPO) {
        $env:GITOPS_REPO = "https://community.opengroup.org/danielscholl/hostk8s"
    }
    if (-not $env:GITOPS_BRANCH) {
        $env:GITOPS_BRANCH = "main"
    }

    # Export variables for template substitution
    $env:REPO_NAME = (Split-Path $env:GITOPS_REPO -Leaf) -replace '\.git$', ''
    $env:SOFTWARE_STACK = $StackName

    # Apply shared GitRepository template with stack-specific name
    Apply-StackYaml "software/stacks/repository.yaml" "Configuring GitOps repository for stack: $StackName"

    # Apply bootstrap kustomization - different for extension vs local stacks
    if ($StackName -match "^extension/") {
        Log-Info "Setting up GitOps bootstrap configuration for extension stack"
        # Create dynamic bootstrap for extension stack
        $bootstrapYaml = @"
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: bootstrap-stack
  namespace: flux-system
spec:
  interval: 1m
  retryInterval: 30s
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: extension-stack-system
  path: ./software/stacks/$StackName
  targetNamespace: flux-system
  prune: true
  wait: false
"@
        $bootstrapYaml | kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" apply -f -
    } else {
        Apply-StackYaml "software/stacks/bootstrap.yaml" "Setting up GitOps bootstrap configuration"
    }

    # Wait for GitRepository to sync
    Log-Info "Waiting for GitRepository to sync..."
    $timeout = 60
    $synced = $false
    while ($timeout -gt 0) {
        try {
            $gitRepoStatus = kubectl --kubeconfig="$($env:KUBECONFIG_PATH)" get gitrepository -n flux-system -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>$null
            if ($gitRepoStatus -match "True") {
                Log-Info "GitRepository synced successfully"
                $synced = $true
                break
            }
        } catch {
            # Continue waiting
        }
        Start-Sleep -Seconds 2
        $timeout -= 2
    }

    if (-not $synced) {
        Log-Warn "GitRepository sync timed out, but continuing..."
    }

    # Show deployment status
    Log-Info "Software stack '$StackName' deployment completed!"
    Log-Info "GitOps Status:"
    $env:KUBECONFIG = $env:KUBECONFIG_PATH

    # Show filtered GitOps status (align with bash script approach)
    try {
        $gitOutput = flux get sources git 2>&1
        if ($LASTEXITCODE -eq 0 -and $gitOutput) {
            $gitOutput -split "`n" | ForEach-Object { Write-Host $_ }

            Write-Host ""
            $kustomizationOutput = flux get kustomizations 2>&1
            if ($LASTEXITCODE -eq 0 -and $kustomizationOutput) {
                $kustomizationOutput -split "`n" | ForEach-Object { Write-Host $_ }
            }
        }
    } catch {
        Log-Warn "Could not get flux status"
    }

    Log-Success "Software stack '$StackName' deployed successfully!"
    Log-Info "Monitor deployment: make status"
    return 0
}

# Run if called directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Main -Arguments $args
    exit $exitCode
}
