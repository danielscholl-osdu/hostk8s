# infra/scripts/setup-registry.ps1 - Setup Container Registry for Windows
# Docker container approach following OpenFaaS/Kind pattern

$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"  # Prevent secret exposure
. "$PSScriptRoot\common.ps1"

# Load environment configuration
Load-Environment

# Registry configuration
$REGISTRY_NAME = 'hostk8s-registry'
$REGISTRY_PORT = '5002'  # Use 5002 to avoid conflict with Kind NodePort on 5001
$REGISTRY_INTERNAL_PORT = '5000'

# Get current timestamp for consistent logging
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$timestamp] [Registry] Setting up Container Registry add-on (Docker container)..."

# Validate Docker is running
try {
    docker info >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[$timestamp] [Registry] ❌ Docker is not running. Please start Docker first."
        exit 1
    }
} catch {
    Write-Host "[$timestamp] [Registry] ❌ Docker is not running. Please start Docker first."
    exit 1
}

# Validate cluster is running
try {
    kubectl cluster-info >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[$timestamp] [Registry] ❌ Cluster is not ready. Ensure cluster is started first."
        exit 1
    }
} catch {
    Write-Host "[$timestamp] [Registry] ❌ Cluster is not ready. Ensure cluster is started first."
    exit 1
}

# Create host directory for registry storage if it doesn't exist
$registryDataDir = Join-Path (Get-Location) "data" "registry"
if (-not (Test-Path $registryDataDir)) {
    Write-Host "[$timestamp] [Registry] Creating registry storage directory..."
    New-Item -ItemType Directory -Force -Path $registryDataDir >$null
}

# Ensure registry docker subdirectory exists (required by registry for storage)
$registryDockerDir = "$registryDataDir/docker"
if (-not (Test-Path $registryDockerDir)) {
    Write-Host "[$timestamp] [Registry] Creating registry docker storage subdirectory..."
    New-Item -ItemType Directory -Force -Path $registryDockerDir >$null
}

# Create registry config file if it doesn't exist
$registryConfigFile = Join-Path (Get-Location) "data" "registry-config.yml"
if (-not (Test-Path $registryConfigFile) -or (Test-Path $registryConfigFile -PathType Container)) {
    Write-Host "[$timestamp] [Registry] Creating registry configuration file..."
    @"
version: 0.1
log:
  fields:
    service: registry
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
"@ | Set-Content -Path $registryConfigFile
}

# Function to setup containerd configuration on Kind nodes
function Setup-ContainerdConfig {
    param([string]$node)

    Write-Host "[$timestamp] [Registry] Configuring containerd on node: $node"

    # Create containerd registry config directory
    $cmd = "docker exec `"$node`" mkdir -p `"/etc/containerd/certs.d/localhost:$REGISTRY_INTERNAL_PORT`""
    Invoke-Expression $cmd

    # Create hosts.toml configuration
    $hostsConfig = @"
server = "http://${REGISTRY_NAME}:${REGISTRY_INTERNAL_PORT}"

[host."http://${REGISTRY_NAME}:${REGISTRY_INTERNAL_PORT}"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
"@

    # Use here-string with docker exec
    $escapedHostsConfig = $hostsConfig -replace '"', '\"'
    $cmd = "docker exec `"$node`" sh -c `"cat > /etc/containerd/certs.d/localhost:$REGISTRY_INTERNAL_PORT/hosts.toml << 'EOF'`n$escapedHostsConfig`nEOF`""
    Invoke-Expression $cmd

    # Note: Kind config should already have config_path set, so hosts.toml should work without restart
    # Only modify containerd config if absolutely necessary
    try {
        $cmd = "docker exec `"$node`" grep -q `"config_path.*certs.d`" /etc/containerd/config.toml 2>`$null"
        Invoke-Expression $cmd
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[$timestamp] [Registry] Warning: config_path not found in containerd config"
            Write-Host "[$timestamp] [Registry] Registry may not work properly without containerd reconfiguration"
            # Skip the restart to avoid node disruption - Kind should have config_path already
        } else {
            Write-Host "[$timestamp] [Registry] containerd config_path already configured"
        }
    } catch {
        Write-Host "[$timestamp] [Registry] containerd config_path already configured"
    }
}

# Check if registry container already exists and is running
$skipContainerCreation = $false
try {
    $cmd = "docker inspect `"$REGISTRY_NAME`" 2>`$null"
    Invoke-Expression $cmd >$null
    if ($LASTEXITCODE -eq 0) {
        $cmd = "docker inspect -f '{{.State.Status}}' `"$REGISTRY_NAME`" 2>`$null"
        $containerStatus = Invoke-Expression $cmd
        if ($containerStatus -eq "running") {
            Write-Host "[$timestamp] [Registry] ✅ Container Registry already running"

            # Verify network connectivity
            $cmd = "docker network inspect kind 2>`$null"
            $networkOutput = Invoke-Expression $cmd
            $networkCheck = $networkOutput | Select-String $REGISTRY_NAME
            if ($networkCheck) {
                Write-Host "[$timestamp] [Registry] Registry container connected to Kind network"
            } else {
                Write-Host "[$timestamp] [Registry] Connecting registry to Kind network..."
                $cmd = "docker network connect `"kind`" `"$REGISTRY_NAME`""
                Invoke-Expression $cmd
            }

            # Skip container creation but continue with UI deployment and configuration
            $skipContainerCreation = $true
        } else {
            Write-Host "[$timestamp] [Registry] Registry container exists but not running ($containerStatus)"
            Write-Host "[$timestamp] [Registry] Removing old container..."
            $cmd = "docker rm -f `"$REGISTRY_NAME`" 2>`$null"
            Invoke-Expression $cmd
        }
    }
} catch {
    # Container doesn't exist, continue with creation
}

# Create registry container (if not skipped)
if (-not $skipContainerCreation) {
    Write-Host "[$timestamp] [Registry] Creating Container Registry container..."
    # Convert Windows paths to Unix-style for Docker volume mounts
    $registryDataVolume = $registryDataDir -replace '\\', '/'
    $registryConfigVolume = $registryConfigFile -replace '\\', '/'

    docker run `
      -d --restart=always `
      -p "127.0.0.1:${REGISTRY_PORT}:${REGISTRY_INTERNAL_PORT}" `
      -v "${registryDataVolume}:/var/lib/registry" `
      -v "${registryConfigVolume}:/etc/docker/registry/config.yml" `
      --name $REGISTRY_NAME `
      registry:2

    # Connect registry to Kind network
    Write-Host "[$timestamp] [Registry] Connecting registry to Kind network..."
    $cmd = "docker network connect `"kind`" `"$REGISTRY_NAME`""
    Invoke-Expression $cmd
}

# Configure containerd on all Kind nodes
Write-Host "[$timestamp] [Registry] Configuring containerd on Kind cluster nodes..."
$cmd = "kind get nodes --name `"$env:CLUSTER_NAME`""
$nodes = Invoke-Expression $cmd
foreach ($node in $nodes) {
    if ($node.Trim()) {
        Setup-ContainerdConfig $node.Trim()
    }
}

# Deploy registry UI (conditional on NGINX ingress)
$registryUiDeployed = $false
try {
    $cmd = "kubectl get ingressclass nginx 2>`$null"
    Invoke-Expression $cmd >$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[$timestamp] [Registry] NGINX Ingress detected, installing Registry UI..."

        # Note: hostk8s namespace is created during cluster startup

        $manifestPath = Join-Path (Get-Location) "infra" "manifests" "registry-ui.yaml"
        Write-Host "[$timestamp] [Registry] Applying registry UI manifest: $manifestPath"

        # Apply manifest with error capture
        $cmd = "kubectl apply -f `"$manifestPath`""
        $applyOutput = Invoke-Expression $cmd 2>&1
        $applyExitCode = $LASTEXITCODE

        Write-Host "[$timestamp] [Registry] kubectl apply output: $applyOutput"
        Write-Host "[$timestamp] [Registry] kubectl apply exit code: $applyExitCode"

        if ($applyExitCode -eq 0) {
            $registryUiDeployed = $true

            # Wait for registry UI to be ready
            Write-Host "[$timestamp] [Registry] Waiting for Container Registry UI to be ready..."
            $cmd = "kubectl wait --namespace hostk8s --for=condition=ready pod --selector=app=registry-ui --timeout=120s"
            $waitOutput = Invoke-Expression $cmd 2>&1
            Write-Host "[$timestamp] [Registry] kubectl wait output: $waitOutput"
        } else {
            Write-Host "[$timestamp] [Registry] ❌ Registry UI deployment failed"
            Write-Host "[$timestamp] [Registry] Troubleshooting registry UI deployment..."

            # Check if ingresses were created
            $cmd = "kubectl get ingress -n hostk8s -l hostk8s.addon=registry"
            $ingressList = Invoke-Expression $cmd 2>&1
            Write-Host "[$timestamp] [Registry] Registry ingresses: $ingressList"

            # Check ingress controller logs if UI ingress creation failed
            $cmd = "kubectl get ingress registry-ui -n hostk8s 2>&1"
            $uiIngressStatus = Invoke-Expression $cmd
            Write-Host "[$timestamp] [Registry] UI Ingress status: $uiIngressStatus"

            if ($uiIngressStatus -match "NotFound") {
                Write-Host "[$timestamp] [Registry] ❌ UI Ingress was not created - likely manifest parsing error"
                # Get nginx ingress controller logs for debugging
                $cmd = "kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=10"
                $nginxLogs = Invoke-Expression $cmd 2>&1
                Write-Host "[$timestamp] [Registry] Recent nginx logs: $nginxLogs"
            }
        }
    } else {
        Write-Host "[$timestamp] [Registry] NGINX Ingress not available - Registry UI skipped"
    }
} catch {
    Write-Host "[$timestamp] [Registry] NGINX Ingress not available - Registry UI skipped"
}

# Test registry health
Write-Host "[$timestamp] [Registry] Testing registry connectivity..."
$maxAttempts = 10
$attempt = 1
$healthCheckPassed = $false

while ($attempt -le $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:${REGISTRY_PORT}/v2/" -UseBasicParsing -TimeoutSec 5 2>$null
        if ($response.StatusCode -eq 200) {
            $healthCheckPassed = $true
            break
        }
    } catch {
        # Continue trying
    }

    if ($attempt -eq $maxAttempts) {
        Write-Host "[$timestamp] [Registry] ❌ Registry health check failed"
        exit 1
    }

    Start-Sleep 3
    $attempt++
}

# Create local registry hosting ConfigMap (Kubernetes standard)
$configMapYaml = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
"@

try {
    $configMapYaml | kubectl apply -f - >$null 2>&1
} catch {
    # ConfigMap creation failed, but continue
}

Write-Host "[$timestamp] [Registry] ✅ Container Registry setup complete"
Write-Host "[$timestamp] [Registry] Access registry API at http://localhost:${REGISTRY_PORT}"
if ($registryUiDeployed) {
    Write-Host "[$timestamp] [Registry] Web UI available at http://registry.localhost:8080"
}
