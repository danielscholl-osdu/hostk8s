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

# Note: Preserving kubeconfig for 'make up' (use 'make clean' for complete removal)

log_success "Cluster '${CYAN}${CLUSTER_NAME}${NC}' deleted successfully"
