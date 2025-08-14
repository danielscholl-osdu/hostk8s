#!/bin/bash
set -euo pipefail

# Deploy or remove GitOps software stack to/from existing HostK8s cluster

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Load environment configuration
load_environment

show_usage() {
    echo "Usage: $0 [down] [STACK_NAME]"
    echo ""
    echo "Deploy or remove a software stack to/from the cluster."
    echo ""
    echo "Arguments:"
    echo "  down        Remove mode - removes the stack"
    echo "  STACK_NAME  Stack to deploy/remove"
    echo ""
    echo "Environment Variables:"
    echo "  SOFTWARE_STACK  Stack name (alternative to STACK_NAME argument)"
    echo ""
    echo "Examples:"
    echo "  SOFTWARE_STACK=sample $0        # Deploy sample stack"
    echo "  $0 down sample                  # Remove sample stack"
    echo "  $0 down extension/my-stack      # Remove extension stack"
}

# Handle command line arguments
OPERATION="$1"
if [ "$OPERATION" = "down" ]; then
    SOFTWARE_STACK="${2:-${SOFTWARE_STACK:-}}"
    if [ -z "$SOFTWARE_STACK" ]; then
        log_error "Stack name must be specified for down operation"
        show_usage
        exit 1
    fi
else
    # Legacy mode - first argument is the stack name
    SOFTWARE_STACK="${OPERATION:-${SOFTWARE_STACK:-}}"
    OPERATION="deploy"
fi

# Validate required parameters
if [ -z "${SOFTWARE_STACK:-}" ]; then
    log_error "SOFTWARE_STACK must be specified"
    show_usage
    exit 1
fi

# Function to remove a software stack
remove_stack() {
    # Check if cluster exists
    if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist"
        exit 1
    fi

    # Set up kubeconfig if needed
    if [ ! -f "${KUBECONFIG_PATH}" ]; then
        log_info "Setting up kubeconfig..."
        mkdir -p data/kubeconfig
        kind export kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KUBECONFIG_PATH}"
    fi

    # Check if cluster is ready
    if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" cluster-info >/dev/null 2>&1; then
        log_error "Cluster '${CLUSTER_NAME}' is not ready"
        exit 1
    fi

    log_info "Removing bootstrap kustomization for stack: $SOFTWARE_STACK"

    # Remove the bootstrap kustomization - Flux will automatically clean up all deployed resources
    if kubectl --kubeconfig="$KUBECONFIG_PATH" delete kustomization bootstrap-stack -n flux-system 2>/dev/null; then
        log_success "Bootstrap kustomization deleted - Flux will clean up all stack resources"
    else
        log_warn "Bootstrap kustomization not found (stack may already be removed)"
    fi

    # Optionally clean up the GitRepository (be careful with shared repos)
    if [[ "$SOFTWARE_STACK" == extension/* ]]; then
        log_info "Cleaning up extension GitRepository..."
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete gitrepository extension-stack-system -n flux-system 2>/dev/null || log_debug "Extension GitRepository already cleaned up"
    else
        log_info "Keeping main GitRepository (shared with HostK8s)"
    fi

    log_success "Software stack '$SOFTWARE_STACK' removal initiated"
    log_info "Flux will complete the cleanup automatically (may take 1-2 minutes)"
    log_info "Monitor with: kubectl get all --all-namespaces | grep -v flux-system"
}

# Execute the requested operation
if [ "$OPERATION" = "down" ]; then
    log_start "Removing software stack '${SOFTWARE_STACK}'..."
    remove_stack
    exit 0
else
    log_start "Deploying software stack '${SOFTWARE_STACK}'..."
fi

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_error "Cluster '${CLUSTER_NAME}' does not exist"
    log_error "Create cluster first: make start"
    exit 1
fi

# Set up kubeconfig if needed
if [ ! -f "${KUBECONFIG_PATH}" ]; then
    log_info "Setting up kubeconfig for existing cluster..."
    mkdir -p data/kubeconfig
    kind export kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KUBECONFIG_PATH}"
fi

# Check if cluster is ready
if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" cluster-info >/dev/null 2>&1; then
    log_error "Cluster '${CLUSTER_NAME}' is not ready"
    exit 1
fi

# Check if Flux is installed, install if not
if ! kubectl --kubeconfig="${KUBECONFIG_PATH}" get namespace flux-system >/dev/null 2>&1; then
    log_info "Flux not found. Installing Flux first..."
    FLUX_ENABLED=true ./infra/scripts/setup-flux.sh
elif ! kubectl --kubeconfig="${KUBECONFIG_PATH}" get pods -n flux-system -l app.kubernetes.io/part-of=flux | grep -q Running; then
    log_info "Flux installation incomplete. Completing installation..."
    FLUX_ENABLED=true ./infra/scripts/setup-flux.sh
else
    log_info "Flux is already installed and running"
fi

# Deploy the software stack
log_info "Deploying software stack '${SOFTWARE_STACK}'..."

# Set GitOps repository defaults for stack deployment
GITOPS_REPO=${GITOPS_REPO:-"https://community.opengroup.org/danielscholl/hostk8s"}
GITOPS_BRANCH=${GITOPS_BRANCH:-"main"}

# Export variables for template substitution
REPO_NAME=$(basename "$GITOPS_REPO" .git)
export REPO_NAME GITOPS_REPO GITOPS_BRANCH SOFTWARE_STACK KUBECONFIG_PATH

# Function to apply stamp YAML files with template substitution support
apply_stack_yaml() {
    local yaml_file="$1"
    local description="$2"

    if [ -f "$yaml_file" ]; then
        log_info "$description"
        # Check if this is an extension stack that needs template processing
        if [[ "$yaml_file" == *"extension/"* ]]; then
            log_debug "Processing template variables for extension stack"
            envsubst < "$yaml_file" | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log_warn "Failed to apply $description"
        else
            kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "$yaml_file" || log_warn "Failed to apply $description"
        fi
    else
        log_error "Stack configuration not found: $yaml_file"
        log_error "Available stacks:"
        find software/stacks -mindepth 1 -maxdepth 1 -type d | sed 's|software/stacks/||' || true
        exit 1
    fi
}

# Apply stack GitRepository first
apply_stack_yaml "software/stacks/$SOFTWARE_STACK/repository.yaml" "Configuring GitOps repository for stack: ${SOFTWARE_STACK}"

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
    apply_stack_yaml "software/stacks/bootstrap.yaml" "Setting up GitOps bootstrap configuration"
fi

# Wait for GitRepository to sync
log_info "Waiting for GitRepository to sync..."
timeout=60
while [ $timeout -gt 0 ]; do
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get gitrepository -n flux-system -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
        log_info "GitRepository synced successfully"
        break
    fi
    sleep 2
    timeout=$((timeout - 2))
done

if [ $timeout -le 0 ]; then
    log_warn "GitRepository sync timed out, but continuing..."
fi

# Show deployment status
log_info "Software stack '${SOFTWARE_STACK}' deployment completed!"
log_info "GitOps Status:"
export KUBECONFIG="$KUBECONFIG_PATH"

# Show filtered GitOps status (only sources and kustomizations)
if flux get sources git 2>/dev/null; then
    echo
    flux get kustomizations 2>/dev/null || true
else
    log_warn "Could not get flux status"
fi

log_success "Software stack '${SOFTWARE_STACK}' deployed successfully!"
log_info "Monitor deployment: make status"
