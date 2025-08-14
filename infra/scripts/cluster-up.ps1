# infra/scripts/cluster-up.ps1 - Create Kind cluster for Windows
param([string]$ConfigName = "")

. "$PSScriptRoot\common.ps1"

# Handle KIND_CONFIG from command line argument
if ($ConfigName) {
    $env:KIND_CONFIG = $ConfigName
}

# Validate required tools are installed
function Test-Dependencies {
    $missingTools = @()

    $tools = @("kind", "kubectl", "helm", "docker")
    foreach ($tool in $tools) {
        if (-not (Test-Command $tool)) {
            $missingTools += $tool
        }
    }

    if ($missingTools.Count -gt 0) {
        Log-Error "Missing required tools: $($missingTools -join ', ')"
        Log-Error "Run 'make install' to install missing dependencies"
        exit 1
    }

    # Check if Docker is running
    try {
        $null = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Docker is not running. Please start Docker Desktop first."
            exit 1
        }
    } catch {
        Log-Error "Docker is not running. Please start Docker Desktop first."
        exit 1
    }
}

# Validate Docker resource allocation
function Test-DockerResources {
    Log-Debug "Checking Docker resource allocation..."

    try {
        $dockerInfo = docker system info --format 'json' 2>$null | ConvertFrom-Json

        if ($dockerInfo) {
            $memoryBytes = $dockerInfo.MemTotal
            $cpus = $dockerInfo.NCPU

            # Convert bytes to GB
            $memoryGB = [math]::Floor($memoryBytes / 1024 / 1024 / 1024)

            Log-Debug "Docker resources: ${memoryGB}GB memory, ${cpus} CPUs"

            # Validate minimum requirements
            if ($memoryGB -lt 4) {
                Log-Warn "Docker has only ${memoryGB}GB memory allocated. Recommend 4GB+ for better performance"
                Log-Warn "Increase in Docker Desktop -> Settings -> Resources -> Memory"
            }

            if ($cpus -lt 2) {
                Log-Warn "Docker has only ${cpus} CPUs allocated. Recommend 2+ for better performance"
                Log-Warn "Increase in Docker Desktop -> Settings -> Resources -> CPUs"
            }

            # Check available disk space
            $drive = (Get-Location).Drive
            $freeSpace = [math]::Round((Get-PSDrive $drive.Name).Free / 1GB, 1)
            if ($freeSpace -lt 10) {
                Log-Warn "Low disk space: ${freeSpace}GB available. Recommend 10GB+ free space"
            }
        } else {
            Log-Warn "Could not retrieve Docker system information"
        }
    } catch {
        Log-Warn "Could not retrieve Docker system information: $_"
    }
}

# Cleanup function for partial failures
function Invoke-CleanupOnFailure {
    Log-Debug "Cleaning up partial installation..."
    try {
        kind delete cluster --name $env:CLUSTER_NAME 2>$null
    } catch { }

    try {
        $kubeconfigPath = Join-Path "data" "kubeconfig" "config"
        if (Test-Path $kubeconfigPath) {
            Remove-Item $kubeconfigPath -Force
        }
    } catch { }
}

# Retry function with exponential backoff
function Invoke-RetryWithBackoff {
    param(
        [string]$Description,
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$InitialDelay = 5
    )

    $attempt = 1
    $delay = $InitialDelay

    while ($attempt -le $MaxAttempts) {
        Log-Debug "Attempt $attempt`: $Description"

        try {
            $result = & $ScriptBlock
            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                return $true
            }
        } catch {
            # Continue to retry logic
        }

        if ($attempt -eq $MaxAttempts) {
            Log-Error "Failed after $MaxAttempts attempts: $Description"
            return $false
        }

        Log-Warn "Attempt $attempt failed, retrying in ${delay}s..."
        Start-Sleep -Seconds $delay
        $delay = $delay * 2
        $attempt++
    }
}

Log-Start "Starting HostK8s cluster setup..."

# Validate dependencies first
Test-Dependencies

# Validate Docker resources
Test-DockerResources

# Set up error handling
$originalErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    # Check if cluster already exists
    $existingClusters = kind get clusters 2>$null
    if ($LASTEXITCODE -eq 0 -and $existingClusters -contains $env:CLUSTER_NAME) {
        Log-Warn "Cluster '$($env:CLUSTER_NAME)' already exists. Use 'make restart' to recreate it."
        exit 1
    }

    # Determine Kind configuration file with 3-tier fallback:
    # 1. KIND_CONFIG environment variable (if set)
    # 2. kind-config.yaml (if exists)
    # 3. kind-custom.yaml (functional defaults)

    $kindConfigFile = ""
    $kindConfigPath = ""

    if ($env:KIND_CONFIG) {
        # KIND_CONFIG explicitly set - use it
        if ($env:KIND_CONFIG.StartsWith("extension/")) {
            # Extension config (format: extension/name)
            $extensionName = $env:KIND_CONFIG.Substring(10)
            $kindConfigFile = "extension/kind-$extensionName.yaml"
        } elseif ($env:KIND_CONFIG.EndsWith(".yaml")) {
            # Direct filename
            $kindConfigFile = $env:KIND_CONFIG
        } else {
            # Named config (auto-discover kind-*.yaml files)
            $configPath = "infra/kubernetes/kind-$($env:KIND_CONFIG).yaml"
            if (Test-Path $configPath) {
                $kindConfigFile = "kind-$($env:KIND_CONFIG).yaml"
            } else {
                Log-Error "Unknown config name: $($env:KIND_CONFIG)"
                Log-Error "Available configurations:"
                $configs = Get-ChildItem "infra/kubernetes/kind-*.yaml" -ErrorAction SilentlyContinue
                if ($configs) {
                    $configs | ForEach-Object { Log-Error "  $($_.BaseName -replace '^kind-', '')" }
                } else {
                    Log-Error "  No configurations found"
                }
                Log-Error "Extension configs: extension/your-config-name"
                Log-Error "Or use full filename like: kind-custom.yaml"
                exit 1
            }
        }
        $kindConfigPath = Join-Path "infra" "kubernetes" $kindConfigFile
    } elseif (Test-Path "infra/kubernetes/kind-config.yaml") {
        # User has a custom kind-config.yaml - use it
        $kindConfigFile = "kind-config.yaml"
        $kindConfigPath = "infra/kubernetes/kind-config.yaml"
    } else {
        # No config specified and no kind-config.yaml - use functional defaults
        $kindConfigFile = "kind-custom.yaml"
        $kindConfigPath = "infra/kubernetes/kind-custom.yaml"
    }

    # Validate config file exists (if one was specified)
    if ($kindConfigPath -and -not (Test-Path $kindConfigPath)) {
        Log-Error "Kind config file not found: $kindConfigPath"
        Log-Error "Available configs:"
        $configs = Get-ChildItem "infra/kubernetes/kind-*.yaml" -ErrorAction SilentlyContinue
        if ($configs) {
            $configs | ForEach-Object { Log-Error "  $($_.Name)" }
        }
        if (Test-Path "infra/kubernetes/extension") {
            Log-Error "Extension configs:"
            $extensionConfigs = Get-ChildItem "infra/kubernetes/extension/kind-*.yaml" -ErrorAction SilentlyContinue
            $extensionConfigs | ForEach-Object {
                $name = $_.BaseName -replace '^kind-', ''
                Log-Error "  extension/$name"
            }
        }
        exit 1
    }

    # Show cluster configuration (only in debug mode)
    if ($env:LOG_LEVEL -ne "info") {
        Log-Section-Start
        Log-Status "Kind Cluster Configuration"
        Write-Host "  Cluster Name: " -NoNewline; Write-Host $env:CLUSTER_NAME -ForegroundColor Cyan
        Write-Host "  Kubernetes Version: " -NoNewline; Write-Host $env:K8S_VERSION -ForegroundColor Cyan
        Write-Host "  Configuration File: " -NoNewline; Write-Host $kindConfigFile -ForegroundColor Cyan
        Log-Section-End
    }

    # Create Kind cluster with retry logic
    Log-Info "Creating Kind cluster..."
    $success = Invoke-RetryWithBackoff -Description "Creating Kind cluster" -ScriptBlock {
        kind create cluster --name $env:CLUSTER_NAME --config $kindConfigPath --image "kindest/node:$($env:K8S_VERSION)" --wait 300s
    }

    if (-not $success) {
        exit 1
    }

    # Export kubeconfig
    Log-Debug "Setting up kubeconfig..."
    $kubeconfigDir = Join-Path "data" "kubeconfig"
    if (-not (Test-Path $kubeconfigDir)) {
        New-Item -ItemType Directory -Path $kubeconfigDir -Force | Out-Null
    }

    $kubeconfigPath = Join-Path $kubeconfigDir "config"
    kind export kubeconfig --name $env:CLUSTER_NAME --kubeconfig $kubeconfigPath

    # Set up kubectl context
    $env:KUBECONFIG = (Resolve-Path $kubeconfigPath).Path

    # Fix kubeconfig for CI environment (if needed)
    if ($env:KIND_CONFIG -eq "ci") {
        Log-Debug "Applying CI-specific kubeconfig fixes..."
        $kubeconfigContent = Get-Content $kubeconfigPath -Raw
        $kubeconfigContent = $kubeconfigContent -replace 'localhost|0\.0\.0\.0', 'docker'
        Set-Content -Path $kubeconfigPath -Value $kubeconfigContent
        Log-Debug "Kubeconfig updated for CI docker-in-docker networking"
    }

    # Wait for cluster to be ready with retry
    Log-Debug "Waiting for cluster nodes to be ready..."
    $success = Invoke-RetryWithBackoff -Description "Waiting for nodes to be ready" -ScriptBlock {
        kubectl wait --for=condition=Ready nodes --all --timeout=300s
    }

    if (-not $success) {
        exit 1
    }

    # Show cluster status
    Log-Debug "Cluster status:"
    kubectl get nodes

    # Setup add-ons if enabled
    if ($env:METALLB_ENABLED -eq "true") {
        Log-Info "Setting up MetalLB..."
        $metallbScript = Join-Path $PSScriptRoot "setup-metallb.ps1"
        if (Test-Path $metallbScript) {
            try {
                $env:KUBECONFIG = (Resolve-Path $kubeconfigPath).Path
                & $metallbScript
            } catch {
                Log-Warn "MetalLB setup failed, continuing..."
            }
        } else {
            Log-Warn "MetalLB setup script not found, skipping..."
        }
    }

    if ($env:INGRESS_ENABLED -eq "true") {
        Log-Info "Setting up NGINX Ingress..."
        $ingressScript = Join-Path $PSScriptRoot "setup-ingress.ps1"
        if (Test-Path $ingressScript) {
            try {
                $env:KUBECONFIG = (Resolve-Path $kubeconfigPath).Path
                & $ingressScript
            } catch {
                Log-Warn "Ingress setup failed, continuing..."
            }
        } else {
            Log-Warn "Ingress setup script not found, skipping..."
        }
    }

    if ($env:FLUX_ENABLED -eq "true") {
        Log-Info "Setting up Flux GitOps..."
        $fluxScript = Join-Path $PSScriptRoot "setup-flux.ps1"
        if (Test-Path $fluxScript) {
            try {
                $env:KUBECONFIG = (Resolve-Path $kubeconfigPath).Path
                & $fluxScript
            } catch {
                Log-Warn "Flux setup failed, continuing..."
            }
        } else {
            Log-Warn "Flux setup script not found, skipping..."
        }
    }

    Log-Success "Kind cluster '$($env:CLUSTER_NAME)' is ready!"

} catch {
    Log-Error "Cluster setup failed: $_"
    Invoke-CleanupOnFailure
    exit 1
} finally {
    $ErrorActionPreference = $originalErrorActionPreference
}
