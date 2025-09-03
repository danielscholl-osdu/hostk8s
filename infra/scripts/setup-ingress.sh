#!/bin/bash
set -euo pipefail
set +x  # Prevent secret exposure

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Custom logging prefix for ingress addon
log_ingress() {
    log_info "[Ingress] $*"
}

log_ingress_warn() {
    log_warn "[Ingress] $*"
}

log_ingress_error() {
    log_error "[Ingress] $*"
}

# Function for error handling
error_exit() {
    log_ingress_error "$1"
    exit 1
}

# Auto-detect execution environment and set kubeconfig path
detect_kubeconfig() {
    if [ -n "${KUBECONFIG:-}" ]; then
        KUBECONFIG_PATH="${KUBECONFIG}"
        log_ingress "Using KUBECONFIG environment variable: $KUBECONFIG_PATH"
    elif [ -f "/kubeconfig/config" ]; then
        KUBECONFIG_PATH="/kubeconfig/config"  # Container mode
        log_ingress "Using container kubeconfig: $KUBECONFIG_PATH"
    elif [ -f "${PWD}/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="${PWD}/data/kubeconfig/config"  # Host mode
        log_ingress "Using host-mode kubeconfig: $KUBECONFIG_PATH"
    else
        error_exit "No kubeconfig found. Ensure cluster is running."
    fi
}

detect_kubeconfig

log_ingress "Setting up NGINX Ingress Controller..."

# Check if NGINX Ingress is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace hostk8s >/dev/null 2>&1; then
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get deployment ingress-nginx-controller -n hostk8s >/dev/null 2>&1; then
        log_ingress "NGINX Ingress already installed, checking if running..."
        if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n hostk8s -l app.kubernetes.io/name=ingress-nginx | grep -q Running; then
            log_ingress "NGINX Ingress appears to already be running"
            # Skip container creation but continue with configuration
            skip_nginx_creation=true
        fi
    fi
fi

# Install NGINX Ingress Controller for Kind (if not skipped)
if [ "${skip_nginx_creation:-false}" != "true" ]; then
    log_ingress "Installing NGINX Ingress Controller..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "${PWD}/infra/manifests/nginx-ingress.yaml" || error_exit "Failed to install NGINX Ingress Controller"
fi

# Check if MetalLB is installed and configure LoadBalancer service
if kubectl --kubeconfig="$KUBECONFIG_PATH" get deployment speaker -n hostk8s >/dev/null 2>&1; then
    log_ingress "MetalLB detected, configuring NGINX Ingress for LoadBalancer integration..."

    # Wait for the ingress controller service to be created first
    kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller -n hostk8s --timeout=60s || log_ingress_warn "Ingress service not found"

    # Patch the service to use LoadBalancer type with correct NodePorts for Kind
    kubectl --kubeconfig="$KUBECONFIG_PATH" patch service ingress-nginx-controller -n hostk8s -p '{
        "spec": {
            "type": "LoadBalancer",
            "ports": [
                {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
            ]
        }
    }' || log_ingress_warn "Failed to patch ingress service for LoadBalancer"

    log_ingress "Ingress controller configured for MetalLB LoadBalancer"
else
    log_ingress "MetalLB not detected, configuring NodePort for Kind port mapping..."

    # Wait for the ingress controller service to be created first
    kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller -n hostk8s --timeout=60s || log_ingress_warn "Ingress service not found"

    # Patch the service to use specific NodePorts that match Kind port mapping (30080->8080, 30443->8443)
    kubectl --kubeconfig="$KUBECONFIG_PATH" patch service ingress-nginx-controller -n hostk8s -p '{
        "spec": {
            "type": "NodePort",
            "ports": [
                {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
            ]
        }
    }' || log_ingress_warn "Failed to patch ingress service for NodePort"

    log_ingress "Ingress controller configured for Kind NodePort mapping (30080->8080, 30443->8443)"
fi

# Wait for NGINX Ingress pods to be ready
log_ingress "Waiting for NGINX Ingress Controller to be ready..."

# Increase timeout for CI environments
INGRESS_TIMEOUT=300s
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    log_ingress "CI environment detected, increasing timeout to 600s for Ingress readiness..."
    INGRESS_TIMEOUT=600s
fi

# First, wait for the deployment to be ready
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace hostk8s \
  --for=condition=available deployment/ingress-nginx-controller \
  --timeout=$INGRESS_TIMEOUT || {
    log_ingress_warn "Ingress deployment not ready, checking pod status..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n hostk8s
    kubectl --kubeconfig="$KUBECONFIG_PATH" describe pods -n hostk8s
}

# Then wait for pods to be ready
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace hostk8s \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=$INGRESS_TIMEOUT || {
    log_ingress_warn "NGINX Ingress Controller failed to become ready within $INGRESS_TIMEOUT"
    log_ingress "Checking ingress controller status..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n hostk8s
    kubectl --kubeconfig="$KUBECONFIG_PATH" logs -n hostk8s -l app.kubernetes.io/component=controller --tail=50
    log_ingress "Continuing without waiting for ingress readiness..."
}

# Wait for admission webhook jobs to complete
log_ingress "Waiting for admission webhook setup jobs to complete..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace hostk8s \
  --for=condition=complete job \
  --selector=app.kubernetes.io/component=admission-webhook \
  --timeout=120s || log_ingress_warn "Admission webhook jobs did not complete in time, continuing..."

# Verify admission webhook is configured
log_ingress "Verifying admission webhook configuration..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get validatingwebhookconfiguration ingress-nginx-admission >/dev/null 2>&1; then
    log_ingress "✅ Admission webhook successfully configured"
else
    log_ingress_warn "Admission webhook configuration not found"
fi


log_ingress "NGINX Ingress Controller setup complete"
log_ingress "Access your applications at http://localhost or https://localhost"
