#!/bin/bash
set -euo pipefail

# Source environment variables (suppress output to prevent secret exposure)
if [ -f .env ]; then
    set +x  # Temporarily disable debug mode
    export $(grep -v '^#' .env | xargs) 2>/dev/null
    [[ $- == *x* ]] && set -x  # Re-enable debug mode if it was on
fi

CLUSTER_NAME=${CLUSTER_NAME:-osdu-ci}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $*"
}

log "Stopping OSDU Kind cluster..."

# Check if cluster exists
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    warn "Cluster '${CLUSTER_NAME}' does not exist"
    exit 0
fi

# Delete the cluster
log "Deleting Kind cluster '${CLUSTER_NAME}'..."
kind delete cluster --name "${CLUSTER_NAME}"

# Clean up kubeconfig
log "Cleaning up kubeconfig..."
rm -f data/kubeconfig/config

log "✅ Cluster '${CLUSTER_NAME}' deleted successfully"