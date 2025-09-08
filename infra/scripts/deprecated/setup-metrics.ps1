# infra/scripts/setup-metrics.ps1 - Setup Metrics Server for Windows
$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"  # Prevent secret exposure
. "$PSScriptRoot\common.ps1"

# Load environment configuration
Load-Environment

# Get current timestamp for consistent logging
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$timestamp] [Metrics] Setting up Metrics Server add-on..."

# Validate cluster is running
try {
    kubectl cluster-info >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Cluster is not ready. Ensure cluster is started first."
        exit 1
    }
} catch {
    Log-Error "Cluster is not ready. Ensure cluster is started first."
    exit 1
}

# Check if metrics server should be disabled
if ($env:METRICS_DISABLED -eq "true") {
    Write-Host "[$timestamp] [Metrics] ⏭️  Metrics Server disabled by METRICS_DISABLED=true"
    exit 0
}

# Check if metrics-server is already installed
try {
    $cmd = "kubectl --kubeconfig=`"$env:KUBECONFIG_PATH`" get deployment metrics-server -n kube-system 2>`$null"
    $null = Invoke-Expression $cmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[$timestamp] [Metrics] ✅ Metrics Server already installed"
        exit 0
    }
} catch {
    # Deployment not found, continue with installation
}

# Install Metrics Server
Write-Host "[$timestamp] [Metrics] Installing Metrics Server from local manifest..."
try {
    $cmd = "kubectl --kubeconfig=`"$env:KUBECONFIG_PATH`" apply -f `"$(Get-Location)/infra/manifests/metrics-server.yaml`""
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to apply Metrics Server manifest"
        exit 1
    }
} catch {
    Log-Error "Failed to apply Metrics Server manifest: $_"
    exit 1
}

# Wait for metrics-server deployment to be ready
Write-Host "[$timestamp] [Metrics] Waiting for Metrics Server to be ready..."
try {
    $cmd = "kubectl --kubeconfig=`"$env:KUBECONFIG_PATH`" wait --namespace kube-system --for=condition=available deployment/metrics-server --timeout=120s"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        Log-Warn "Metrics Server deployment not ready within 2 minutes"
        exit 1
    }
} catch {
    Log-Warn "Metrics Server deployment not ready within 2 minutes"
    exit 1
}

# Wait for metrics-server API to be available
Write-Host "[$timestamp] [Metrics] Waiting for Metrics API to be available..."
$maxAttempts = 20
$attempt = 1

while ($attempt -le $maxAttempts) {
    try {
        $cmd = "kubectl --kubeconfig=`"$env:KUBECONFIG_PATH`" top nodes 2>`$null"
        Invoke-Expression $cmd
        if ($LASTEXITCODE -eq 0) {
            break
        }
    } catch {
        # Continue trying
    }

    if ($attempt -eq $maxAttempts) {
        Log-Warn "Metrics API not available after $maxAttempts attempts"
        break
    }

    Start-Sleep 3
    $attempt++
}

Write-Host "[$timestamp] [Metrics] ✅ Metrics Server setup complete"
Write-Host "[$timestamp] [Metrics] Try: kubectl top nodes"
Write-Host "[$timestamp] [Metrics] Try: kubectl top pods --all-namespaces"
