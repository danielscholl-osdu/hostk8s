#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Load environment configuration
load_environment

# Setting up Metrics Server
log_info "[Metrics] Setting up Metrics Server add-on..."

# Validate cluster is running
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "Cluster is not ready. Ensure cluster is started first."
    exit 1
fi

# Check if metrics server should be disabled
if [[ "${METRICS_DISABLED:-false}" == "true" ]]; then
    log_info "[Metrics] ⏭️  Metrics Server disabled by METRICS_DISABLED=true"
    exit 0
fi

# Check if metrics-server is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get deployment metrics-server -n kube-system >/dev/null 2>&1; then
    log_info "[Metrics] ✅ Metrics Server already installed"
    exit 0
fi

# Install Metrics Server
log_info "[Metrics] Installing Metrics Server from local manifest..."
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "${PWD}/infra/manifests/metrics-server.yaml"; then
    log_error "Failed to apply Metrics Server manifest"
    exit 1
fi

# Wait for metrics-server deployment to be ready
log_info "[Metrics] Waiting for Metrics Server to be ready..."
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" wait --namespace kube-system \
    --for=condition=available deployment/metrics-server \
    --timeout=120s; then
    log_warn "Metrics Server deployment not ready within 2 minutes"
    exit 1
fi

# Wait for metrics-server API to be available
log_info "[Metrics] Waiting for Metrics API to be available..."
max_attempts=20
attempt=1
while [ $attempt -le $max_attempts ]; do
    if kubectl --kubeconfig="$KUBECONFIG_PATH" top nodes >/dev/null 2>&1; then
        break
    fi

    if [ $attempt -eq $max_attempts ]; then
        log_warn "Metrics API not available after ${max_attempts} attempts"
        break
    fi

    sleep 3
    attempt=$((attempt + 1))
done

log_info "[Metrics] ✅ Metrics Server setup complete"
log_info "[Metrics] Try: kubectl top nodes"
log_info "[Metrics] Try: kubectl top pods --all-namespaces"
