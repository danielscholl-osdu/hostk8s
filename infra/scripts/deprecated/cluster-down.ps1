# infra/scripts/cluster-down.ps1 - Stop HostK8s cluster for Windows
. "$PSScriptRoot\common.ps1"

Log-Start "Stopping HostK8s cluster..."

try {
    # Check if cluster exists
    $existingClusters = kind get clusters 2>$null
    if ($LASTEXITCODE -ne 0 -or $existingClusters -notcontains $env:CLUSTER_NAME) {
        Log-Warn "Cluster '$($env:CLUSTER_NAME)' does not exist"
        exit 0
    }

    # Delete the cluster
    Log-Debug "Deleting Kind cluster '$($env:CLUSTER_NAME)'..."
    kind delete cluster --name $env:CLUSTER_NAME

    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to delete cluster '$($env:CLUSTER_NAME)'"
        exit 1
    }

    # Note: Preserving kubeconfig for 'make start' (use 'make clean' for complete removal)

    Log-Success "Cluster '$($env:CLUSTER_NAME)' deleted successfully"

} catch {
    Log-Error "Failed to stop cluster: $_"
    exit 1
}
