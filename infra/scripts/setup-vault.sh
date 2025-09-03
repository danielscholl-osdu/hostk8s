#!/bin/bash
set -euo pipefail

# Source common utilities
source "$(dirname "$0")/common.sh"

#######################################
# Setup Vault using Helm
#######################################

# Check if Vault is already installed
if helm list -n hostk8s 2>/dev/null | grep -q "^vault\\s"; then
    log_info "Vault already installed via Helm"
    if kubectl get pod -l app.kubernetes.io/name=vault -n hostk8s 2>/dev/null | grep -q Running; then
        log_info "Vault is already running"
        exit 0
    fi
fi

log_info "Setting up Vault secret management addon..."

# Add HashiCorp Helm repository
log_debug "Adding HashiCorp Helm repository..."
helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || {
    log_debug "HashiCorp repo already exists"
}
helm repo update >/dev/null 2>&1

# Install Vault in dev mode (lightweight for development)
log_info "Installing Vault in dev mode..."
helm upgrade --install vault hashicorp/vault \
    --namespace hostk8s \
    --create-namespace \
    --set "server.dev.enabled=true" \
    --set "server.dev.devRootToken=hostk8s" \
    --set "injector.enabled=false" \
    --set "server.resources.requests.memory=64Mi" \
    --set "server.resources.requests.cpu=10m" \
    --set "server.resources.limits.memory=128Mi" \
    --set "server.resources.limits.cpu=100m" \
    --set "ui.enabled=true" \
    --set "ui.serviceType=ClusterIP" \
    --wait --timeout 2m >/dev/null 2>&1 || {
    log_error "Failed to install Vault"
    exit 1
}

# Wait for Vault to be ready
log_info "Waiting for Vault to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n hostk8s --timeout=120s || {
    log_warn "Vault not ready after 120s, checking status..."
    kubectl get pod -l app.kubernetes.io/name=vault -n hostk8s
}

# Optional: Install External Secrets Operator if needed for GitOps integration
if [[ "${EXTERNAL_SECRETS_ENABLED:-false}" == "true" ]]; then
    log_info "Installing External Secrets Operator..."

    # Add External Secrets Helm repository
    helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1
    helm repo update >/dev/null 2>&1

    # Install External Secrets Operator
    helm upgrade --install external-secrets external-secrets/external-secrets \
        --namespace hostk8s \
        --set installCRDs=true \
        --set webhook.port=9443 \
        --set resources.requests.memory=32Mi \
        --set resources.requests.cpu=10m \
        --set resources.limits.memory=64Mi \
        --set resources.limits.cpu=50m \
        --wait --timeout 2m || {
        log_warn "Failed to install External Secrets Operator"
    }

    # Create ClusterSecretStore for Vault
    log_debug "Creating Vault ClusterSecretStore..."
    cat <<EOF | kubectl apply -f - || log_warn "Failed to create ClusterSecretStore"
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
EOF
fi

# Setup Vault UI ingress if NGINX is available and ready
if kubectl get deployment -n hostk8s ingress-nginx-controller >/dev/null 2>&1; then
    log_info "NGINX Ingress detected, waiting for readiness..."

    # Wait for NGINX Ingress controller to be ready (up to 30 seconds)
    if kubectl wait --for=condition=available deployment/ingress-nginx-controller -n hostk8s --timeout=30s >/dev/null 2>&1; then
        log_info "NGINX Ingress ready, configuring Vault UI ingress..."
        kubectl apply -f infra/manifests/vault-ingress.yaml >/dev/null 2>&1 || {
            log_warn "Failed to configure Vault UI ingress"
        }
    else
        log_warn "NGINX Ingress not ready within 30 seconds, skipping Vault UI ingress setup"
        log_warn "You can manually apply: kubectl apply -f infra/manifests/vault-ingress.yaml"
    fi
fi

# Show addon status
log_debug "Vault addon status:"
kubectl get pods -n hostk8s -l app.kubernetes.io/name=vault || true

log_success "Vault secret management addon installed successfully!"
log_info "Vault is running in dev mode with token: hostk8s"

# Show access information based on ingress availability
if kubectl get ingress vault-ui -n hostk8s >/dev/null 2>&1; then
    log_info "Vault UI available at: http://localhost:8080/ui/"
    log_info "Login with token: hostk8s"
else
    log_info "Vault UI available at: http://vault.hostk8s.svc.cluster.local:8200"
    log_info ""
    log_info "To access Vault:"
    log_info "  export VAULT_ADDR='http://127.0.0.1:8200'"
    log_info "  export VAULT_TOKEN='hostk8s'"
    log_info "  kubectl port-forward -n hostk8s svc/vault 8200:8200 &"
fi
log_info ""
log_info "To use Vault CLI:"
log_info "  kubectl exec -n hostk8s vault-0 -- vault kv put secret/myapp key=value"
