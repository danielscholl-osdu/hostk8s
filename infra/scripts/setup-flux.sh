#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [Flux] $*"
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
    elif [ -f "$(pwd)/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"  # Host mode
        log "Using host-mode kubeconfig: $KUBECONFIG_PATH"
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

    log "✅ Flux CLI verified: $flux_version"
}

detect_kubeconfig

# Set GitOps repository defaults
GITOPS_REPO=${GITOPS_REPO:-"https://community.opengroup.org/danielscholl/osdu-ci"}
GITOPS_BRANCH=${GITOPS_BRANCH:-"main"}
GITOPS_STAMP=${GITOPS_STAMP:-"sample"}

log "Setting up Flux GitOps..."
log "GitOps Repository: $GITOPS_REPO"
log "GitOps Branch: $GITOPS_BRANCH"
log "GitOps Stamp: $GITOPS_STAMP"

# Check if Flux is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace flux-system >/dev/null 2>&1; then
    log "Flux namespace already exists, checking if installation is complete..."
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n flux-system -l app.kubernetes.io/part-of=flux | grep -q Running; then
        log "Flux appears to already be running"

        # Show flux status
        export KUBECONFIG="$KUBECONFIG_PATH"
        if command -v flux >/dev/null 2>&1; then
            log "Current Flux status:"
            flux get all || log "WARNING: Could not get flux status"
        fi
        exit 0
    fi
fi

# Check and install flux CLI
check_flux_cli

# Install Flux
log "Installing Flux controllers..."
export KUBECONFIG="$KUBECONFIG_PATH"

# Install Flux with minimal components for development
flux install \
    --components-extra=image-reflector-controller,image-automation-controller \
    --network-policy=false \
    --watch-all-namespaces=true || error_exit "Failed to install Flux"

# Wait for Flux controllers to be ready
log "Waiting for Flux controllers to be ready..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux -n flux-system --timeout=600s || log "WARNING: Some controllers may still be starting, but continuing..."

# Create a GitRepository source using configured repository
log "Creating GitRepository source..."
cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log "WARNING: Failed to create GitRepository"
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: osdu-ci
  namespace: flux-system
spec:
  interval: 1m
  url: $GITOPS_REPO
  ref:
    branch: $GITOPS_BRANCH
  ignore: |
    # exclude all
    /*
    # include only GitOps stamp directory
    !/software/stamp/
EOF

# Create a Kustomization for the specified stamp directory
log "Creating Kustomization for stamp: $GITOPS_STAMP"
cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log "WARNING: Failed to create Kustomization"
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: osdu-ci-stamp
  namespace: flux-system
spec:
  interval: 5m
  path: "./software/stamp/$GITOPS_STAMP"
  prune: true
  sourceRef:
    kind: GitRepository
    name: osdu-ci
EOF

# Show Flux installation status
log "Flux installation completed! Checking status..."
flux get all || log "WARNING: Could not get flux status"

log "✅ Flux GitOps setup complete!"
log ""
log "🚀 Active Configuration:"
log "   Repository: $GITOPS_REPO"
log "   Branch: $GITOPS_BRANCH"
log "   Stamp: $GITOPS_STAMP"
log "   Path: ./software/stamp/$GITOPS_STAMP"
log ""
log "🔧 Management commands:"
log "1. Check status: flux get all"
log "2. Monitor logs: flux logs --follow"
log "3. Switch stamp: export GITOPS_STAMP=new-stamp && make restart"
log "4. View resources: kubectl get all --all-namespaces"
log ""
log "📖 Documentation: https://fluxcd.io/flux/get-started/"
