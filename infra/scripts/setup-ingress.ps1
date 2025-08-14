# infra/scripts/setup-ingress.ps1 - Setup NGINX Ingress for Windows
. "$PSScriptRoot\common.ps1"

Log-Info "Setting up NGINX Ingress Controller..."

# Basic ingress installation using kubectl
try {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    if ($LASTEXITCODE -eq 0) {
        Log-Success "NGINX Ingress Controller deployment initiated"

        # Wait for service to be created first
        Log-Info "Waiting for ingress service to be created..."
        kubectl wait --namespace ingress-nginx --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller --timeout=60s

        # Patch the service to use specific NodePorts that match Kind port mapping (30080->8080, 30443->8443)
        Log-Info "Configuring service for Kind NodePort mapping..."

        # Create temp file with patch JSON (simplest approach)
        $tempPatch = [System.IO.Path]::GetTempFileName()
        $patchContent = @'
{
    "spec": {
        "type": "NodePort",
        "ports": [
            {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
            {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
        ]
    }
}
'@
        Set-Content -Path $tempPatch -Value $patchContent

        kubectl patch service ingress-nginx-controller -n ingress-nginx --type=merge --patch-file=$tempPatch
        Remove-Item $tempPatch -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -eq 0) {
            Log-Success "Ingress controller configured for Kind NodePort mapping (30080->8080, 30443->8443)"
        } else {
            Log-Warn "Failed to patch ingress service for NodePort"
        }

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
