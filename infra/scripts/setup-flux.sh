#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source common utilities
source "$(dirname "$0")/common.sh"

# Function for error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Auto-detect execution environment and set kubeconfig path
detect_kubeconfig() {
    if [ -n "${KUBECONFIG:-}" ]; then
        KUBECONFIG_PATH="${KUBECONFIG}"
    elif [ -f "/kubeconfig/config" ]; then
        KUBECONFIG_PATH="/kubeconfig/config"  # Container mode
        log_info "Using container kubeconfig: $KUBECONFIG_PATH"
    elif [ -f "${PWD}/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="${PWD}/data/kubeconfig/config"  # Host mode
        log_info "Using host-mode kubeconfig: $KUBECONFIG_PATH"
    else
        error_exit "No kubeconfig found. Ensure cluster is running."
    fi
}

# Function to check if flux CLI is available
check_flux_cli() {
    if ! command -v flux >/dev/null 2>&1; then
        error_exit "Flux CLI not found. Install it first with 'make install' or manually: https://fluxcd.io/flux/installation/"
    fi

    # Verify flux CLI is working and check version
    local flux_version
    if ! flux_version=$(flux version --client 2>/dev/null | head -1); then
        error_exit "Flux CLI found but not working properly"
    fi

    log_debug "Flux CLI verified: ${CYAN}$flux_version${NC}"
}

detect_kubeconfig

# Set GitOps repository defaults
GITOPS_REPO=${GITOPS_REPO:-"https://community.opengroup.org/danielscholl/hostk8s"}
GITOPS_BRANCH=${GITOPS_BRANCH:-"main"}
# Set default value first
SOFTWARE_STACK=${SOFTWARE_STACK:-""}

# SOFTWARE_STACK should only be set explicitly via environment variable or make command
# No auto-detection to prevent unexpected behavior

# Show Flux configuration (only in debug mode)
if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
    log_section_start
    log_status "Flux GitOps Configuration"
    log_debug "  Repository: ${CYAN}$GITOPS_REPO${NC}"
    log_debug "  Branch: ${CYAN}$GITOPS_BRANCH${NC}"
    if [ -n "$SOFTWARE_STACK" ]; then
        log_debug "  Stack: ${CYAN}$SOFTWARE_STACK${NC}"
    else
        log_debug "  Stack: ${CYAN}Not configured (Flux only)${NC}"
    fi
    log_section_end
fi

# Check if Flux is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace flux-system >/dev/null 2>&1; then
    log_info "Flux namespace already exists, checking if installation is complete..."
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n flux-system -l app.kubernetes.io/part-of=flux | grep -q Running; then
        log_info "Flux appears to already be running"

        # Show flux status
        export KUBECONFIG="$KUBECONFIG_PATH"
        if command -v flux >/dev/null 2>&1; then
            log_info "Current Flux status:"
            flux get all || log_warn "Could not get flux status"
        fi
        exit 0
    fi
fi

# Check and install flux CLI
check_flux_cli

# Install Flux
log_info "Installing Flux controllers..."
export KUBECONFIG="$KUBECONFIG_PATH"

# Install Flux with minimal components for development
flux install \
    --components-extra=image-reflector-controller,image-automation-controller \
    --network-policy=false \
    --watch-all-namespaces=true || error_exit "Failed to install Flux"

# Wait for Flux controllers to be ready
log_info "Waiting for Flux controllers to be ready..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux -n flux-system --timeout=600s || log_warn "Flux controllers still initializing, continuing setup..."

# Function to apply stamp YAML files with template substitution support
apply_stamp_yaml() {
    local yaml_file="$1"
    local description="$2"

    if [ -f "$yaml_file" ]; then
        log_info "$description"
        # Check if this is an extension stack that needs template processing
        if [[ "$yaml_file" == *"extension/"* ]]; then
            log_debug "Processing template variables for extension stack"
            envsubst < "$yaml_file" | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log_info "WARNING: Failed to apply $description"
        else
            kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "$yaml_file" || log_info "WARNING: Failed to apply $description"
        fi
    else
        log_info "WARNING: YAML file not found: $yaml_file"
    fi
}

# Only create GitOps configuration if a stack is specified
if [ -n "$SOFTWARE_STACK" ]; then
    # Extract repository name from URL for better naming
    REPO_NAME=$(basename "$GITOPS_REPO" .git)

    # Export variables for template substitution
    export REPO_NAME GITOPS_REPO GITOPS_BRANCH SOFTWARE_STACK

    # Apply stack GitRepository first
    apply_stamp_yaml "software/stacks/$SOFTWARE_STACK/repository.yaml" "Configuring GitOps repository for stack: ${CYAN}$SOFTWARE_STACK${NC}"

    # Apply bootstrap kustomization - different for extension vs local stacks
    if [[ "$SOFTWARE_STACK" == extension/* ]]; then
        log_info "Setting up GitOps bootstrap configuration for extension stack"
        # Create dynamic bootstrap for extension stack
        cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: bootstrap-stack
  namespace: flux-system
spec:
  interval: 1m
  retryInterval: 30s
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: extension-stack-system
  path: ./software/stacks/${SOFTWARE_STACK}
  targetNamespace: flux-system
  prune: true
  wait: false
EOF
    else
        apply_stamp_yaml "software/stacks/bootstrap.yaml" "Setting up GitOps bootstrap configuration"
    fi
else
    log_info "No stack specified - Flux installed without GitOps configuration"
    log_info "To configure a stack later, set SOFTWARE_STACK and run: make restart"
fi

# Show Flux installation status
log_info "Flux installation completed! Checking status..."
flux get all || log_warn "Could not get flux status"

log_info "Flux GitOps setup complete!"
if [ -n "$SOFTWARE_STACK" ]; then
    log_debug "Active Configuration:"
    log_debug "  Repository: ${CYAN}$GITOPS_REPO${NC}"
    log_debug "  Branch: ${CYAN}$GITOPS_BRANCH${NC}"
    log_debug "  Stack: ${CYAN}$SOFTWARE_STACK${NC}"
    log_debug "  Path: ${CYAN}./software/stacks/$SOFTWARE_STACK${NC}"
fi
