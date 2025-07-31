#!/bin/bash
set -euo pipefail

# Quick development cycle for host-mode Kind clusters

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

log "Starting development cycle..."

# Stop existing cluster
log "Stopping existing cluster..."
./infra/scripts/cluster-down.sh

# Start fresh cluster
log "Starting fresh cluster..."
./infra/scripts/cluster-up.sh

log "✅ Development cycle complete!"