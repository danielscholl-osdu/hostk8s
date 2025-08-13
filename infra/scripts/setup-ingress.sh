#!/bin/bash
set -euo pipefail

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [Ingress] $*"
}

# Function for error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Auto-detect execution environment and set kubeconfig path
detect_kubeconfig() {
    if [ -n "${KUBECONFIG:-}" ]; then
        KUBECONFIG_PATH="${KUBECONFIG}"
        log "Using KUBECONFIG environment variable: $KUBECONFIG_PATH"
    elif [ -f "/kubeconfig/config" ]; then
        KUBECONFIG_PATH="/kubeconfig/config"  # Container mode
        log "Using container kubeconfig: $KUBECONFIG_PATH"
    elif [ -f "${PWD}/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="${PWD}/data/kubeconfig/config"  # Host mode
        log "Using host-mode kubeconfig: $KUBECONFIG_PATH"
    else
        error_exit "No kubeconfig found. Ensure cluster is running."
    fi
}

detect_kubeconfig

log "Setting up NGINX Ingress Controller..."

# Check if NGINX Ingress is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace ingress-nginx >/dev/null 2>&1; then
    log "NGINX Ingress namespace already exists, checking if installation is complete..."
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx | grep -q Running; then
        log "NGINX Ingress appears to already be running"
        exit 0
    fi
fi

# Install NGINX Ingress Controller for Kind
log "Installing NGINX Ingress Controller..."
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/kind/deploy.yaml || error_exit "Failed to install NGINX Ingress Controller"

# Check if MetalLB is installed and configure LoadBalancer service
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace metallb-system >/dev/null 2>&1; then
    log "MetalLB detected, configuring NGINX Ingress for LoadBalancer integration..."

    # Wait for the ingress controller service to be created first
    kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller -n ingress-nginx --timeout=60s || log "WARNING: Ingress service not found"

    # Patch the service to use LoadBalancer type with correct NodePorts for Kind
    kubectl --kubeconfig="$KUBECONFIG_PATH" patch service ingress-nginx-controller -n ingress-nginx -p '{
        "spec": {
            "type": "LoadBalancer",
            "ports": [
                {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
            ]
        }
    }' || log "WARNING: Failed to patch ingress service for LoadBalancer"

    log "Ingress controller configured for MetalLB LoadBalancer"
else
    log "MetalLB not detected, configuring NodePort for Kind port mapping..."

    # Wait for the ingress controller service to be created first
    kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=jsonpath='{.metadata.name}' service/ingress-nginx-controller -n ingress-nginx --timeout=60s || log "WARNING: Ingress service not found"

    # Patch the service to use specific NodePorts that match Kind port mapping (30080->8080, 30443->8443)
    kubectl --kubeconfig="$KUBECONFIG_PATH" patch service ingress-nginx-controller -n ingress-nginx -p '{
        "spec": {
            "type": "NodePort",
            "ports": [
                {"name": "http", "port": 80, "protocol": "TCP", "targetPort": "http", "nodePort": 30080},
                {"name": "https", "port": 443, "protocol": "TCP", "targetPort": "https", "nodePort": 30443}
            ]
        }
    }' || log "WARNING: Failed to patch ingress service for NodePort"

    log "Ingress controller configured for Kind NodePort mapping (30080->8080, 30443->8443)"
fi

# Wait for NGINX Ingress pods to be ready
log "Waiting for NGINX Ingress Controller to be ready..."

# Increase timeout for CI environments
INGRESS_TIMEOUT=300s
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
    log "CI environment detected, increasing timeout to 600s for Ingress readiness..."
    INGRESS_TIMEOUT=600s
fi

# First, wait for the deployment to be ready
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace ingress-nginx \
  --for=condition=available deployment/ingress-nginx-controller \
  --timeout=$INGRESS_TIMEOUT || {
    log "WARNING: Ingress deployment not ready, checking pod status..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n ingress-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" describe pods -n ingress-nginx
}

# Then wait for pods to be ready
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=$INGRESS_TIMEOUT || {
    log "WARNING: NGINX Ingress Controller failed to become ready within $INGRESS_TIMEOUT"
    log "Checking ingress controller status..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n ingress-nginx
    kubectl --kubeconfig="$KUBECONFIG_PATH" logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
    log "Continuing without waiting for ingress readiness..."
}

# Wait for admission webhook jobs to complete
log "Waiting for admission webhook setup jobs to complete..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace ingress-nginx \
  --for=condition=complete job \
  --selector=app.kubernetes.io/component=admission-webhook \
  --timeout=120s || log "WARNING: Admission webhook jobs did not complete in time, continuing..."

# Verify admission webhook is configured
log "Verifying admission webhook configuration..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get validatingwebhookconfiguration ingress-nginx-admission >/dev/null 2>&1; then
    log "✅ Admission webhook successfully configured"
else
    log "WARNING: Admission webhook configuration not found"
fi


log "NGINX Ingress Controller setup complete"
log "Access your applications at http://localhost or https://localhost"
