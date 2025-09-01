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

    # First check if the stack is actually deployed
    log_info "Checking if stack '$SOFTWARE_STACK' is deployed..."

    bootstrap_exists=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get kustomization bootstrap-${SOFTWARE_STACK} -n flux-system --no-headers 2>/dev/null || true)

    # Check if bootstrap kustomization exists
    if [ -z "$bootstrap_exists" ]; then
        log_info "Stack '$SOFTWARE_STACK' is not currently deployed"
        log_info "Nothing to remove - stack is already clean"
        return 0
    fi

    log_info "Stack '$SOFTWARE_STACK' found - proceeding with removal"

    # Get all kustomizations BEFORE deleting bootstrap to know what was created by this stack
    # This captures all kustomizations that the stack created (components, apps, etc.)
    all_kustomizations_before=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get kustomizations -n flux-system --no-headers -o custom-columns="NAME:.metadata.name" 2>/dev/null || true)

    # Remove the bootstrap kustomization first
    log_info "Removing bootstrap kustomization: bootstrap-${SOFTWARE_STACK}"
    if kubectl --kubeconfig="$KUBECONFIG_PATH" delete kustomization bootstrap-${SOFTWARE_STACK} -n flux-system 2>/dev/null; then
        log_success "Bootstrap kustomization deleted"
    fi

    # Wait a moment for Flux to start garbage collection
    sleep 2

    # Get remaining kustomizations after bootstrap deletion
    all_kustomizations_after=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get kustomizations -n flux-system --no-headers -o custom-columns="NAME:.metadata.name" 2>/dev/null || true)

    # Find kustomizations that still exist (these were created by the stack but not garbage collected yet)
    # We'll delete any kustomization that starts with "app-${SOFTWARE_STACK}" or "component-"
    if [ -n "$all_kustomizations_after" ]; then
        log_info "Cleaning up remaining stack kustomizations..."
        echo "$all_kustomizations_after" | while read -r kustomization_name; do
            if [ -n "$kustomization_name" ]; then
                # Delete app-specific kustomizations for this stack
                if [[ "$kustomization_name" == "app-${SOFTWARE_STACK}"* ]]; then
                    log_info "Removing application kustomization: $kustomization_name"
                    kubectl --kubeconfig="$KUBECONFIG_PATH" delete kustomization "$kustomization_name" -n flux-system 2>/dev/null || log_debug "Kustomization $kustomization_name already removed"
                # Skip component kustomizations - they are shared across stacks
                elif [[ "$kustomization_name" == "component-"* ]]; then
                    log_debug "Skipping shared component kustomization: $kustomization_name"
                fi
            fi
        done
    fi

    # Clean up only the stack-specific GitRepository, keep flux-system for shared components
    if [[ "$SOFTWARE_STACK" == extension/* ]]; then
        log_info "Cleaning up extension GitRepository..."
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete gitrepository extension-stack-system -n flux-system 2>/dev/null || log_debug "Extension GitRepository already cleaned up"
    else
        log_info "Cleaning up stack-specific GitRepository: flux-system-${SOFTWARE_STACK}"
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete gitrepository "flux-system-${SOFTWARE_STACK}" -n flux-system 2>/dev/null || log_debug "Stack GitRepository already cleaned up"
        log_info "Keeping flux-system GitRepository (shared components repository)"
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
        # Check if this file needs template processing (extension stacks or files with environment variables)
        if [[ "$yaml_file" == *"extension/"* ]] || grep -q '${' "$yaml_file" 2>/dev/null; then
            log_debug "Processing template variables for stack file"
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

# Apply shared GitRepository template with stack-specific name
apply_stack_yaml "software/stacks/repository.yaml" "Configuring GitOps repository for stack: ${SOFTWARE_STACK}"

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
export KUBECONFIG="$KUBECONFIG_PATH"

log_success "Software stack '${SOFTWARE_STACK}' deployed successfully!"
log_info "Monitor deployment: make status"
