#!/bin/bash
set -euo pipefail

# Setup Container Registry add-on for HostK8s cluster
# Following MetalLB/NGINX add-on pattern

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Get current timestamp for consistent logging
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] [Registry] Using KUBECONFIG environment variable: ${KUBECONFIG}"
echo "[$TIMESTAMP] [Registry] Setting up Container Registry add-on..."

# Validate cluster is running
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "[$TIMESTAMP] [Registry] ❌ Cluster is not ready. Ensure cluster is started first."
    exit 1
fi

# Create host directory for registry storage if it doesn't exist
registry_data_dir="${PWD}/data/storage/registry"
if [ ! -d "$registry_data_dir" ]; then
    echo "[$TIMESTAMP] [Registry] Creating registry storage directory..."
    mkdir -p "$registry_data_dir"
fi

# Check if registry namespace already exists
if kubectl get namespace registry >/dev/null 2>&1; then
    # Check if registry is healthy
    if kubectl get pods -n registry -l app=registry-core --field-selector=status.phase=Running | grep -q registry-core; then
        echo "[$TIMESTAMP] [Registry] ✅ Container Registry already running"
        exit 0
    else
        echo "[$TIMESTAMP] [Registry] Registry exists but unhealthy, reinstalling..."
        kubectl delete namespace registry --timeout=60s >/dev/null 2>&1 || true
        sleep 5
    fi
fi

# Deploy registry core (always)
echo "[$TIMESTAMP] [Registry] Installing Container Registry core..."
kubectl apply -f "${PWD}/infra/manifests/registry-core.yaml" || {
    echo "[$TIMESTAMP] [Registry] ❌ Failed to apply registry core manifests"
    exit 1
}

# Deploy registry UI (conditional on NGINX ingress)
registry_ui_deployed=false
if kubectl get ingressclass nginx >/dev/null 2>&1; then
    echo "[$TIMESTAMP] [Registry] NGINX Ingress detected, installing Registry UI..."
    if kubectl apply -f "${PWD}/infra/manifests/registry-ui.yaml"; then
        registry_ui_deployed=true
    fi
else
    echo "[$TIMESTAMP] [Registry] NGINX Ingress not available - Registry UI skipped"
fi

# Wait for registry core to be ready
echo "[$TIMESTAMP] [Registry] Waiting for Container Registry core to be ready..."
kubectl wait --namespace registry --for=condition=ready pod --selector=app=registry-core --timeout=120s >/dev/null || {
    echo "[$TIMESTAMP] [Registry] ❌ Registry core failed to become ready"
    exit 1
}

# Wait for registry UI to be ready (if deployed)
if [ "$registry_ui_deployed" = true ]; then
    echo "[$TIMESTAMP] [Registry] Waiting for Container Registry UI to be ready..."
    kubectl wait --namespace registry --for=condition=ready pod --selector=app=registry-ui --timeout=120s >/dev/null 2>&1 || true
fi

# Test registry health
max_attempts=10
attempt=1
while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:5001/v2/ >/dev/null 2>&1; then
        break
    fi

    if [ $attempt -eq $max_attempts ]; then
        echo "[$TIMESTAMP] [Registry] ❌ Registry health check failed"
        exit 1
    fi

    sleep 3
    attempt=$((attempt + 1))
done

echo "[$TIMESTAMP] [Registry] ✅ Container Registry setup complete"
echo "[$TIMESTAMP] [Registry] Access registry API at http://localhost:5001"
