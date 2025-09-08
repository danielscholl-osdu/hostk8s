#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source shared utilities
source "$(dirname "$0")/common.sh"

log_start "Stopping HostK8s cluster..."

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_warn "Cluster '${CLUSTER_NAME}' does not exist"
    exit 0
fi

# Delete the cluster
log_debug "Deleting Kind cluster '${CYAN}${CLUSTER_NAME}${NC}'..."
kind delete cluster --name "${CLUSTER_NAME}"

# Clean up registry container if it exists
REGISTRY_NAME="hostk8s-registry"
if docker inspect "${REGISTRY_NAME}" >/dev/null 2>&1; then
    log_debug "Removing registry container '${CYAN}${REGISTRY_NAME}${NC}'..."
    docker rm -f "${REGISTRY_NAME}" >/dev/null 2>&1 || true
    log_debug "Registry container removed"
fi

# Note: Preserving kubeconfig for 'make start' (use 'make clean' for complete removal)

log_success "Cluster '${CYAN}${CLUSTER_NAME}${NC}' deleted successfully"
