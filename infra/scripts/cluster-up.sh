#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source environment variables (suppress output to prevent secret exposure)
if [ -f .env ]; then
    set -a  # Enable allexport mode
    source .env
    set +a  # Disable allexport mode
fi

# Set defaults
CLUSTER_NAME=${CLUSTER_NAME:-osdu-ci}
K8S_VERSION=${K8S_VERSION:-v1.33.2}
KIND_CONFIG=${KIND_CONFIG:-default}
METALLB_ENABLED=${METALLB_ENABLED:-false}
INGRESS_ENABLED=${INGRESS_ENABLED:-false}
FLUX_ENABLED=${FLUX_ENABLED:-true}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $*"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $*"
}

# Validate required tools are installed
check_dependencies() {
    local missing_tools=()

    for tool in kind kubectl helm docker; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        log "Install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "kind"|"kubectl"|"helm") log "  brew install $tool" ;;
                "docker") log "  Install Docker Desktop from docker.com" ;;
            esac
        done
        exit 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker Desktop first."
        exit 1
    fi
}

# Validate Docker resource allocation
validate_docker_resources() {
    log "Checking Docker resource allocation..."

    # Get Docker system info
    local docker_info=$(docker system info --format 'json' 2>/dev/null)

    if [ -n "$docker_info" ]; then
        local memory_bytes=$(echo "$docker_info" | jq -r '.MemTotal // 0' 2>/dev/null || echo "0")
        local cpus=$(echo "$docker_info" | jq -r '.NCPU // 0' 2>/dev/null || echo "0")

        # Convert bytes to GB
        local memory_gb=$((memory_bytes / 1024 / 1024 / 1024))

        log "Docker resources: ${memory_gb}GB memory, ${cpus} CPUs"

        # Validate minimum requirements
        if [ "$memory_gb" -lt 4 ]; then
            warn "Docker has only ${memory_gb}GB memory allocated. Recommend 4GB+ for better performance"
            warn "Increase in Docker Desktop -> Settings -> Resources -> Memory"
        fi

        if [ "$cpus" -lt 2 ]; then
            warn "Docker has only ${cpus} CPUs allocated. Recommend 2+ for better performance"
            warn "Increase in Docker Desktop -> Settings -> Resources -> CPUs"
        fi

        # Check available disk space (cross-platform)
        local available_space
        if [[ "$OSTYPE" == "darwin"* ]]; then
            available_space=$(df -g "$(pwd)" | awk 'NR==2 {print $4}')
        else
            available_space=$(df -BG "$(pwd)" | awk 'NR==2 {print $4}' | sed 's/G//')
        fi
        if [ -n "$available_space" ] && [ "$available_space" -lt 10 ]; then
            warn "Low disk space: ${available_space}GB available. Recommend 10GB+ free space"
        fi
    else
        warn "Could not retrieve Docker system information"
    fi
}

log "Starting OSDU Kind cluster setup..."

# Validate dependencies first
check_dependencies

# Validate Docker resources
validate_docker_resources

# Cleanup function for partial failures
cleanup_on_failure() {
    log "Cleaning up partial installation..."
    kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true
    rm -f data/kubeconfig/config 2>/dev/null || true
}

# Set trap for cleanup on script exit due to error
trap 'cleanup_on_failure' ERR

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts=3
    local delay=5
    local attempt=1
    local description="$1"
    shift

    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt: $description"
        if "$@"; then
            return 0
        fi

        if [ $attempt -eq $max_attempts ]; then
            error "Failed after $max_attempts attempts: $description"
            return 1
        fi

        warn "Attempt $attempt failed, retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    warn "Cluster '${CLUSTER_NAME}' already exists. Delete it first with: kind delete cluster --name ${CLUSTER_NAME}"
    exit 1
fi

# Map convention names to actual config files
case "${KIND_CONFIG}" in
    "default")
        KIND_CONFIG_FILE="kind-config.yaml"
        ;;
    "minimal")
        KIND_CONFIG_FILE="kind-config-minimal.yaml"
        ;;
    "simple")
        KIND_CONFIG_FILE="kind-config-simple.yaml"
        ;;
    "ci")
        KIND_CONFIG_FILE="kind-config-ci.yaml"
        ;;
    *)
        # If it doesn't match convention, assume it's a direct filename
        if [[ "${KIND_CONFIG}" == *.yaml ]]; then
            KIND_CONFIG_FILE="${KIND_CONFIG}"
        else
            error "Unknown config name: ${KIND_CONFIG}"
            error "Available options: default, minimal, simple, ci"
            error "Or use full filename like: kind-config-custom.yaml"
            exit 1
        fi
        ;;
esac

KIND_CONFIG_PATH="infra/kubernetes/${KIND_CONFIG_FILE}"
if [ ! -f "${KIND_CONFIG_PATH}" ]; then
    error "Kind config file not found: ${KIND_CONFIG_PATH}"
    error "Available configs:"
    ls -1 infra/kubernetes/kind-config*.yaml 2>/dev/null || error "No kind config files found"
    exit 1
fi

# Create Kind cluster with retry logic
log "Creating Kind cluster '${CLUSTER_NAME}' with Kubernetes ${K8S_VERSION} using ${KIND_CONFIG} (${KIND_CONFIG_FILE})..."
if ! retry_with_backoff "Creating Kind cluster" \
    kind create cluster \
        --name "${CLUSTER_NAME}" \
        --config "${KIND_CONFIG_PATH}" \
        --image "kindest/node:${K8S_VERSION}" \
        --wait 300s; then
    exit 1
fi

# Export kubeconfig
log "Setting up kubeconfig..."
mkdir -p data/kubeconfig
kind export kubeconfig \
    --name "${CLUSTER_NAME}" \
    --kubeconfig data/kubeconfig/config

# Set up kubectl context
export KUBECONFIG=$(pwd)/data/kubeconfig/config

# Fix kubeconfig for CI environment (GitLab CI networking)
if [[ "${KIND_CONFIG}" == "ci" ]]; then
    log "Applying CI-specific kubeconfig fixes for GitLab CI networking..."
    # Replace 0.0.0.0 and localhost with docker hostname for GitLab CI
    sed -i.bak -E -e "s/localhost|0\.0\.0\.0/docker/g" "$(pwd)/data/kubeconfig/config"
    log "Kubeconfig updated for GitLab CI docker-in-docker networking"
fi

# Wait for cluster to be ready with retry
log "Waiting for cluster nodes to be ready..."
if ! retry_with_backoff "Waiting for nodes to be ready" \
    kubectl wait --for=condition=Ready nodes --all --timeout=300s; then
    exit 1
fi

# Show cluster status
log "Cluster status:"
kubectl get nodes

# Setup add-ons if enabled (using host-installed kubectl/helm)
if [[ "${METALLB_ENABLED}" == "true" ]]; then
    log "Setting up MetalLB..."
    if [ -f "infra/scripts/setup-metallb.sh" ]; then
        KUBECONFIG=$(pwd)/data/kubeconfig/config ./infra/scripts/setup-metallb.sh || warn "MetalLB setup failed, continuing..."
    else
        warn "MetalLB setup script not found, skipping..."
    fi
fi

if [[ "${INGRESS_ENABLED}" == "true" ]]; then
    log "Setting up NGINX Ingress..."
    if [ -f "infra/scripts/setup-ingress.sh" ]; then
        KUBECONFIG=$(pwd)/data/kubeconfig/config ./infra/scripts/setup-ingress.sh || warn "Ingress setup failed, continuing..."
    else
        warn "Ingress setup script not found, skipping..."
    fi
fi

if [[ "${FLUX_ENABLED}" == "true" ]]; then
    log "Setting up Flux GitOps..."
    if [ -f "infra/scripts/setup-flux.sh" ]; then
        KUBECONFIG=$(pwd)/data/kubeconfig/config ./infra/scripts/setup-flux.sh || warn "Flux setup failed, continuing..."
    else
        warn "Flux setup script not found, skipping..."
    fi
fi

# Show basic cluster readiness
kubectl get nodes

# Clear trap on successful completion
trap - ERR

log "✅ Kind cluster '${CLUSTER_NAME}' is ready!"
log ""
log "Access your cluster:"
log "  export KUBECONFIG=\$(pwd)/data/kubeconfig/config"
log "  kubectl get nodes"
