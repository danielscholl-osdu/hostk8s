# infra/scripts/setup-ingress.ps1 - Setup NGINX Ingress for Windows
. "$PSScriptRoot\common.ps1"

Log-Info "Setting up NGINX Ingress Controller..."
Log-Warn "Ingress setup for Windows PowerShell is not yet fully implemented"
Log-Info "Please refer to the bash version for complete functionality"
Log-Info "You can run the bash version in WSL if needed"

# Basic ingress installation using kubectl
try {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    if ($LASTEXITCODE -eq 0) {
        Log-Success "NGINX Ingress Controller deployment initiated"
        Log-Info "Waiting for controller to be ready..."
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
        Log-Success "NGINX Ingress Controller is ready"
    } else {
        Log-Error "Failed to deploy NGINX Ingress Controller"
        exit 1
    }
} catch {
    Log-Error "Failed to setup ingress: $_"
    exit 1
}