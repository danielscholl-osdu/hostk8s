#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Quick development cycle for host-mode Kind clusters
# Environment variables:
#   SOFTWARE_STACK - Optional software stack to deploy (e.g., "sample")
#   CLUSTER_NAME   - Cluster name (defaults to "hostk8s")
#   FLUX_ENABLED   - Enable GitOps deployment (defaults based on SOFTWARE_STACK)

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Cleanup function for partial failures
cleanup_on_failure() {
    log_debug "Cleaning up after restart failure..."
    # If cluster-up fails, we're in an inconsistent state
    # Try to clean up but don't fail if cleanup fails
    kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true
    rm -f data/kubeconfig/config 2>/dev/null || true
}

# Set trap for cleanup on script exit due to error
trap 'cleanup_on_failure' ERR

log_start "Starting HostK8s cluster restart..."

# Get script directory for relative paths
SCRIPT_DIR="$(dirname "$0")"

# Show configuration for debugging
log_debug "Cluster configuration:"
log_debug "  Cluster Name: ${CYAN}${CLUSTER_NAME}${NC}"
if [[ -n "${SOFTWARE_STACK:-}" ]]; then
    log_debug "  Software Stack: ${CYAN}${SOFTWARE_STACK}${NC}"
    log_debug "  Flux Enabled: ${CYAN}${FLUX_ENABLED:-auto}${NC}"
else
    log_debug "  Software Stack: ${CYAN}none${NC}"
fi

# Validate that required scripts exist
if [[ ! -f "$SCRIPT_DIR/cluster-down.sh" ]]; then
    log_error "cluster-down.sh not found in $SCRIPT_DIR"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/cluster-up.sh" ]]; then
    log_error "cluster-up.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Stop existing cluster with error handling
log_info "Stopping existing cluster..."
if ! "$SCRIPT_DIR/cluster-down.sh"; then
    log_error "Failed to stop cluster"
    exit 1
fi

# Validate cluster was actually stopped
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_error "Cluster '${CLUSTER_NAME}' still exists after shutdown"
    exit 1
fi

# Start fresh cluster with error handling
log_info "Starting fresh cluster..."
if ! "$SCRIPT_DIR/cluster-up.sh"; then
    log_error "Failed to start cluster"
    exit 1
fi

# Validate cluster is actually running
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "Cluster started but not accessible via kubectl"
    exit 1
fi

# Clear trap on successful completion
trap - ERR

log_success "Cluster restart complete!"
log_info "Cluster '${CYAN}${CLUSTER_NAME}${NC}' is ready for development"

if [[ -n "${SOFTWARE_STACK:-}" ]]; then
    log_info "Software stack '${CYAN}${SOFTWARE_STACK}${NC}' has been deployed"
    if [[ "${FLUX_ENABLED:-false}" == "true" ]]; then
        log_info "GitOps is enabled - changes will sync automatically"
    fi
fi
