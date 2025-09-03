# setup-vault.ps1 - PowerShell version of Vault setup script
$ErrorActionPreference = "Stop"

# Source common utilities
. "$PSScriptRoot\common.ps1"

#######################################
# Setup Vault using Helm
#######################################

# Check if Vault is already installed
try {
    $helmList = helm list -n hostk8s 2>$null | Out-String
    if ($helmList -match "^vault\s") {
        Log-Info "Vault already installed via Helm"
        $vaultPod = kubectl get pod -l app.kubernetes.io/name=vault -n hostk8s 2>$null | Out-String
        if ($vaultPod -match "Running") {
            Log-Info "Vault is already running"
            exit 0
        }
    }
} catch {
    # Continue with installation
}

Log-Info "Setting up Vault secret management addon..."

# Add HashiCorp Helm repository
Log-Debug "Adding HashiCorp Helm repository..."
try {
    helm repo add hashicorp https://helm.releases.hashicorp.com 2>$null | Out-Null
} catch {
    Log-Debug "HashiCorp repo already exists"
}
helm repo update 2>$null | Out-Null

# Install Vault in dev mode (lightweight for development)
Log-Info "Installing Vault in dev mode..."
$helmArgs = @(
    "upgrade", "--install", "vault", "hashicorp/vault",
    "--namespace", "hostk8s",
    "--create-namespace",
    "--set", "server.dev.enabled=true",
    "--set", "server.dev.devRootToken=hostk8s",
    "--set", "injector.enabled=false",
    "--set", "server.resources.requests.memory=64Mi",
    "--set", "server.resources.requests.cpu=10m",
    "--set", "server.resources.limits.memory=128Mi",
    "--set", "server.resources.limits.cpu=100m",
    "--set", "ui.enabled=true",
    "--set", "ui.serviceType=ClusterIP",
    "--wait", "--timeout", "2m"
)

try {
    & helm @helmArgs 2>$null | Out-Null
} catch {
    Log-Error "Failed to install Vault"
    exit 1
}

# Wait for Vault to be ready
Log-Info "Waiting for Vault to be ready..."
try {
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n hostk8s --timeout=120s
} catch {
    Log-Warn "Vault not ready after 120s, checking status..."
    kubectl get pod -l app.kubernetes.io/name=vault -n hostk8s
}

# Optional: Install External Secrets Operator if needed for GitOps integration
if ($env:EXTERNAL_SECRETS_ENABLED -eq "true") {
    Log-Info "Installing External Secrets Operator..."

    # Add External Secrets Helm repository
    helm repo add external-secrets https://charts.external-secrets.io 2>$null | Out-Null
    helm repo update 2>$null | Out-Null

    # Install External Secrets Operator
    $esArgs = @(
        "upgrade", "--install", "external-secrets", "external-secrets/external-secrets",
        "--namespace", "hostk8s",
        "--set", "installCRDs=true",
        "--set", "webhook.port=9443",
        "--set", "resources.requests.memory=32Mi",
        "--set", "resources.requests.cpu=10m",
        "--set", "resources.limits.memory=64Mi",
        "--set", "resources.limits.cpu=50m",
        "--wait", "--timeout", "2m"
    )

    try {
        & helm @esArgs
    } catch {
        Log-Warn "Failed to install External Secrets Operator"
    }

    # Create ClusterSecretStore for Vault
    Log-Debug "Creating Vault ClusterSecretStore..."
    $clusterSecretStore = @"
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "http://vault.hostk8s.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
          namespace: hostk8s
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: hostk8s
type: Opaque
stringData:
  token: "hostk8s"
"@

    try {
        $clusterSecretStore | kubectl apply -f - 2>$null | Out-Null
    } catch {
        Log-Warn "Failed to create ClusterSecretStore"
    }
}

# Setup Vault UI ingress if NGINX is available
try {
    kubectl get deployment -n ingress-nginx ingress-nginx-controller 2>$null | Out-Null
    Log-Info "NGINX Ingress detected, configuring Vault UI ingress..."
    try {
        kubectl apply -f infra/manifests/vault-ingress.yaml 2>$null | Out-Null
    } catch {
        Log-Warn "Failed to configure Vault UI ingress"
    }
} catch {
    # No NGINX detected
}

# Show addon status
Log-Debug "Vault addon status:"
try {
    kubectl get pods -n hostk8s -l app.kubernetes.io/name=vault
} catch {
    # Continue
}

Log-Success "Vault secret management addon installed successfully!"
Log-Info "Vault is running in dev mode with token: hostk8s"

# Show access information based on ingress availability
try {
    kubectl get ingress vault-ui -n hostk8s 2>$null | Out-Null
    Log-Info "Vault UI available at: http://localhost:8080/ui/"
    Log-Info "Login with token: hostk8s"
} catch {
    Log-Info "Vault UI available at: http://vault.hostk8s.svc.cluster.local:8200"
    Log-Info ""
    Log-Info "To access Vault:"
    Log-Info "  `$env:VAULT_ADDR='http://127.0.0.1:8200'"
    Log-Info "  `$env:VAULT_TOKEN='hostk8s'"
    Log-Info "  kubectl port-forward -n hostk8s svc/vault 8200:8200"
}
Log-Info ""
Log-Info "To use Vault CLI:"
Log-Info "  kubectl exec -n hostk8s vault-0 -- vault kv put secret/myapp key=value"
