# infra/scripts/setup-flux.ps1 - Setup Flux GitOps for Windows
. "$PSScriptRoot\common.ps1"

function Test-FluxCLI {
    if (-not (Test-Command "flux")) {
        Log-Error "Flux CLI not found. Install it first with 'make install' or manually: https://fluxcd.io/flux/installation/"
        exit 1
    }

    # Verify flux CLI is working and check version
    try {
        $fluxVersion = flux version --client 2>&1
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Flux CLI found but not working properly. Error: $fluxVersion"
            exit 1
        }
        Log-Debug "Flux CLI verified: $fluxVersion"
    } catch {
        Log-Error "Flux CLI found but not working properly: $_"
        exit 1
    }
}

function Apply-StampYaml {
    param(
        [string]$YamlFile,
        [string]$Description
    )

    if (Test-Path $YamlFile) {
        Log-Info $Description
        # Check if this file needs template processing (extension stacks or files with environment variables)
        $needsTemplateProcessing = ($YamlFile -match "extension/") -or ((Get-Content $YamlFile -Raw) -match '\$\{')
        if ($needsTemplateProcessing) {
            Log-Debug "Processing template variables for stack file"
            # TODO: Implement proper envsubst equivalent for PowerShell
            # For now, simple apply - template processing needs to be implemented
            kubectl apply -f $YamlFile
            if ($LASTEXITCODE -ne 0) {
                Log-Info "WARNING: Failed to apply $Description"
            }
        } else {
            kubectl apply -f $YamlFile
            if ($LASTEXITCODE -ne 0) {
                Log-Info "WARNING: Failed to apply $Description"
            }
        }
    } else {
        Log-Info "WARNING: YAML file not found: $YamlFile"
    }
}

# Set GitOps repository defaults
if (-not $env:GITOPS_REPO) {
    $env:GITOPS_REPO = "https://community.opengroup.org/danielscholl/hostk8s"
}
if (-not $env:GITOPS_BRANCH) {
    $env:GITOPS_BRANCH = "main"
}
if (-not $env:SOFTWARE_STACK) {
    $env:SOFTWARE_STACK = ""
}

# Show Flux configuration (only in debug mode)
if ($env:LOG_LEVEL -ne "info") {
    Log-Section-Start
    Log-Status "Flux GitOps Configuration"
    Log-Debug "  Repository: $($env:GITOPS_REPO)"
    Log-Debug "  Branch: $($env:GITOPS_BRANCH)"
    if ($env:SOFTWARE_STACK) {
        Log-Debug "  Stack: $($env:SOFTWARE_STACK)"
    } else {
        Log-Debug "  Stack: Not configured (Flux only)"
    }
    Log-Section-End
}

# Check if Flux is already installed
try {
    $null = kubectl get namespace flux-system 2>$null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "Flux namespace already exists, checking if installation is complete..."
        $fluxPods = kubectl get pods -n flux-system -l app.kubernetes.io/part-of=flux --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $fluxPods -and ($fluxPods | Where-Object { $_ -match "Running" })) {
            Log-Info "Flux appears to already be running"

            # Show flux status
            if (Test-Command "flux") {
                Log-Info "Current Flux status:"
                flux get all
                if ($LASTEXITCODE -ne 0) {
                    Log-Warn "Could not get flux status"
                }
            }
            return
        } else {
            Write-Host "No resources found in flux-system namespace."
        }
    }
} catch {
    # Namespace doesn't exist, continue with installation
}

# Check and install flux CLI
Test-FluxCLI

# Install Flux
Log-Info "Installing Flux controllers..."

# Install Flux with minimal components for development
flux install --components-extra=image-reflector-controller,image-automation-controller --network-policy=false --watch-all-namespaces=true
if ($LASTEXITCODE -ne 0) {
    Log-Error "Failed to install Flux"
    exit 1
}

# Wait for Flux controllers to be ready
Log-Info "Waiting for Flux controllers to be ready..."
try {
    kubectl wait --for=condition=available deployment -l app.kubernetes.io/part-of=flux -n flux-system --timeout=600s 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "error: no matching resources found"
        Log-Warn "! Flux controllers still initializing, continuing setup..."
    }
} catch {
    Write-Host "error: no matching resources found"
    Log-Warn "! Flux controllers still initializing, continuing setup..."
}

# Only create GitOps configuration if a stack is specified
if ($env:SOFTWARE_STACK) {
    # Extract repository name from URL for better naming
    $repoName = (Split-Path $env:GITOPS_REPO -Leaf) -replace '\.git$', ''

    # Apply stack GitRepository first
    Apply-StampYaml "software/stacks/$($env:SOFTWARE_STACK)/repository.yaml" "Configuring GitOps repository for stack: $($env:SOFTWARE_STACK)"

    # Apply bootstrap kustomization - different for extension vs local stacks
    if ($env:SOFTWARE_STACK -match "^extension/") {
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
  path: ./software/stacks/$($env:SOFTWARE_STACK)
  targetNamespace: flux-system
  prune: true
  wait: false
"@
        $bootstrapYaml | kubectl apply -f -
    } else {
        Apply-StampYaml "software/stacks/bootstrap.yaml" "Setting up GitOps bootstrap configuration"
    }
} else {
    Log-Info "No stack specified - Flux installed without GitOps configuration"
    Log-Info "To configure a stack later, set SOFTWARE_STACK and run: make restart"
}

# Show Flux installation status
Log-Info "Flux installation completed! Checking status..."
try {
    flux get all
    if ($LASTEXITCODE -ne 0) {
        Log-Warn "Could not get flux status"
    }
} catch {
    Log-Warn "Could not get flux status"
}

Log-Success "Flux GitOps setup complete!"
if ($env:SOFTWARE_STACK) {
    Log-Debug "Active Configuration:"
    Log-Debug "  Repository: $($env:GITOPS_REPO)"
    Log-Debug "  Branch: $($env:GITOPS_BRANCH)"
    Log-Debug "  Stack: $($env:SOFTWARE_STACK)"
    Log-Debug "  Path: ./software/stacks/$($env:SOFTWARE_STACK)"
}
