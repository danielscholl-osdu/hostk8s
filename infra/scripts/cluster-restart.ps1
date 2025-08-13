# infra/scripts/cluster-restart.ps1 - Quick cluster restart for development
# Environment variables:
#   SOFTWARE_STACK - Optional software stack to deploy (e.g., "sample")
#   CLUSTER_NAME   - Cluster name (defaults to "hostk8s")
#   FLUX_ENABLED   - Enable GitOps deployment (defaults based on SOFTWARE_STACK)

. "$PSScriptRoot\common.ps1"

# Cleanup function for partial failures
function Invoke-CleanupOnFailure {
    Log-Debug "Cleaning up after restart failure..."
    # If cluster-up fails, we're in an inconsistent state
    # Try to clean up but don't fail if cleanup fails
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

Log-Start "Starting HostK8s cluster restart..."

# Set up error handling
$originalErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    # Show configuration for debugging
    Log-Debug "Cluster configuration:"
    Log-Debug "  Cluster Name: $($env:CLUSTER_NAME)"
    if ($env:SOFTWARE_STACK) {
        Log-Debug "  Software Stack: $($env:SOFTWARE_STACK)"
        Log-Debug "  Flux Enabled: $($env:FLUX_ENABLED)"
    } else {
        Log-Debug "  Software Stack: none"
    }
    
    # Validate that required scripts exist
    $clusterDownScript = Join-Path $PSScriptRoot "cluster-down.ps1"
    $clusterUpScript = Join-Path $PSScriptRoot "cluster-up.ps1"
    
    if (-not (Test-Path $clusterDownScript)) {
        Log-Error "cluster-down.ps1 not found in $PSScriptRoot"
        exit 1
    }
    
    if (-not (Test-Path $clusterUpScript)) {
        Log-Error "cluster-up.ps1 not found in $PSScriptRoot"
        exit 1
    }
    
    # Stop existing cluster with error handling
    Log-Info "Stopping existing cluster..."
    try {
        & $clusterDownScript
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to stop cluster"
            exit 1
        }
    } catch {
        Log-Error "Failed to stop cluster: $_"
        exit 1
    }
    
    # Validate cluster was actually stopped
    $existingClusters = kind get clusters 2>$null
    if ($LASTEXITCODE -eq 0 -and $existingClusters -contains $env:CLUSTER_NAME) {
        Log-Error "Cluster '$($env:CLUSTER_NAME)' still exists after shutdown"
        exit 1
    }
    
    # Start fresh cluster with error handling
    Log-Info "Starting fresh cluster..."
    try {
        & $clusterUpScript
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to start cluster"
            exit 1
        }
    } catch {
        Log-Error "Failed to start cluster: $_"
        exit 1
    }
    
    # Validate cluster is actually running
    try {
        $null = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Cluster started but not accessible via kubectl"
            exit 1
        }
    } catch {
        Log-Error "Cluster started but not accessible via kubectl: $_"
        exit 1
    }
    
    Log-Success "Cluster restart complete!"
    Log-Info "Cluster '$($env:CLUSTER_NAME)' is ready for development"
    
    if ($env:SOFTWARE_STACK) {
        Log-Info "Software stack '$($env:SOFTWARE_STACK)' has been deployed"
        if ($env:FLUX_ENABLED -eq "true") {
            Log-Info "GitOps is enabled - changes will sync automatically"
        }
    }
    
} catch {
    Log-Error "Cluster restart failed: $_"
    Invoke-CleanupOnFailure
    exit 1
} finally {
    $ErrorActionPreference = $originalErrorActionPreference
}