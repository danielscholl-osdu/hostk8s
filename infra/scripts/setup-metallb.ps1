# infra/scripts/setup-metallb.ps1 - Setup MetalLB for Windows
. "$PSScriptRoot\common.ps1"

Log-Info "Setting up MetalLB LoadBalancer..."
Log-Warn "MetalLB setup for Windows PowerShell is not yet fully implemented"
Log-Info "Please refer to the bash version for complete functionality"
Log-Info "You can run the bash version in WSL if needed"

# Basic MetalLB installation using kubectl
try {
    # Install MetalLB
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
    
    if ($LASTEXITCODE -eq 0) {
        Log-Success "MetalLB deployment initiated"
        Log-Info "Waiting for MetalLB to be ready..."
        kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=300s
        Log-Success "MetalLB is ready"
        
        # TODO: Configure IP address pool for Kind cluster
        Log-Info "IP address pool configuration not implemented in PowerShell version"
        Log-Info "Use the bash version or configure manually"
    } else {
        Log-Error "Failed to deploy MetalLB"
        exit 1
    }
} catch {
    Log-Error "Failed to setup MetalLB: $_"
    exit 1
}