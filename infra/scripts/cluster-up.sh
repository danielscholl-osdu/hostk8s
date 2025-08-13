#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Validate required tools are installed
check_dependencies() {
    local missing_tools=()

    for tool in kind kubectl helm docker; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_debug "Install missing tools:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "kind"|"kubectl"|"helm") log_debug "  brew install $tool" ;;
                "docker") log_debug "  Install Docker Desktop from docker.com" ;;
            esac
        done
        exit 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker Desktop first."
        exit 1
    fi
}

# Validate Docker resource allocation
validate_docker_resources() {
    log_debug "Checking Docker resource allocation..."

    # Get Docker system info
    local docker_info=$(docker system info --format 'json' 2>/dev/null)

    if [ -n "$docker_info" ]; then
        local memory_bytes=$(echo "$docker_info" | jq -r '.MemTotal // 0' 2>/dev/null || echo "0")
        local cpus=$(echo "$docker_info" | jq -r '.NCPU // 0' 2>/dev/null || echo "0")

        # Convert bytes to GB
        local memory_gb=$((memory_bytes / 1024 / 1024 / 1024))

        log_debug "Docker resources: ${CYAN}${memory_gb}GB${NC} memory, ${CYAN}${cpus}${NC} CPUs"

        # Validate minimum requirements
        if [ "$memory_gb" -lt 4 ]; then
            log_warn "Docker has only ${memory_gb}GB memory allocated. Recommend 4GB+ for better performance"
            log_warn "Increase in Docker Desktop -> Settings -> Resources -> Memory"
        fi

        if [ "$cpus" -lt 2 ]; then
            log_warn "Docker has only ${cpus} CPUs allocated. Recommend 2+ for better performance"
            log_warn "Increase in Docker Desktop -> Settings -> Resources -> CPUs"
        fi

        # Check available disk space (cross-platform)
        local available_space
        if [[ "$OSTYPE" == "darwin"* ]]; then
            available_space=$(df -g "$(pwd)" | awk 'NR==2 {print $4}')
        else
            available_space=$(df -BG "$(pwd)" | awk 'NR==2 {print $4}' | sed 's/G//')
        fi
        if [ -n "$available_space" ] && [ "$available_space" -lt 10 ]; then
            log_warn "Low disk space: ${available_space}GB available. Recommend 10GB+ free space"
        fi
    else
        log_warn "Could not retrieve Docker system information"
    fi
}

log_start "Starting HostK8s cluster setup..."

# Validate dependencies first
check_dependencies

# Validate Docker resources
validate_docker_resources

# Cleanup function for partial failures
cleanup_on_failure() {
    log_debug "Cleaning up partial installation..."
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
        log_debug "Attempt $attempt: $description"
        if "$@"; then
            return 0
        fi

        if [ $attempt -eq $max_attempts ]; then
            log_error "Failed after $max_attempts attempts: $description"
            return 1
        fi

        log_warn "Attempt $attempt failed, retrying in ${delay}s..."
        sleep $delay
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log_warn "Cluster '${CLUSTER_NAME}' already exists. Use 'make restart' to recreate it."
    exit 1
fi

# Determine Kind configuration file with 3-tier fallback:
# 1. KIND_CONFIG environment variable (if set)
# 2. kind-config.yaml (if exists)
# 3. No config (use Kind defaults)

KIND_CONFIG_FILE=""
KIND_CONFIG_PATH=""

if [ -n "${KIND_CONFIG}" ]; then
    # KIND_CONFIG explicitly set - use it
    if [[ "${KIND_CONFIG}" == extension/* ]]; then
        # Extension config (format: extension/name)
        EXTENSION_NAME="${KIND_CONFIG#extension/}"
        KIND_CONFIG_FILE="extension/kind-${EXTENSION_NAME}.yaml"
    elif [[ "${KIND_CONFIG}" == *.yaml ]]; then
        # Direct filename
        KIND_CONFIG_FILE="${KIND_CONFIG}"
    elif [ -f "infra/kubernetes/kind-${KIND_CONFIG}.yaml" ]; then
        # Named config (auto-discover kind-*.yaml files)
        KIND_CONFIG_FILE="kind-${KIND_CONFIG}.yaml"
    else
        log_error "Unknown config name: ${KIND_CONFIG}"
        log_error "Available configurations:"
        find infra/kubernetes -name "kind-*.yaml" -exec basename {} .yaml \; | sed 's/kind-/  /' | sort 2>/dev/null || echo "  No configurations found"
        log_error "Extension configs: extension/your-config-name"
        log_error "Or use full filename like: kind-custom.yaml"
        exit 1
    fi
    KIND_CONFIG_PATH="infra/kubernetes/${KIND_CONFIG_FILE}"
elif [ -f "infra/kubernetes/kind-config.yaml" ]; then
    # User has a custom kind-config.yaml - use it
    KIND_CONFIG_FILE="kind-config.yaml"
    KIND_CONFIG_PATH="infra/kubernetes/${KIND_CONFIG_FILE}"
else
    # No config specified and no kind-config.yaml - use functional defaults
    KIND_CONFIG_FILE="kind-custom.yaml"
    KIND_CONFIG_PATH="infra/kubernetes/${KIND_CONFIG_FILE}"
fi

# Validate config file exists (if one was specified)
if [ -n "${KIND_CONFIG_PATH}" ] && [ ! -f "${KIND_CONFIG_PATH}" ]; then
    log_error "Kind config file not found: ${KIND_CONFIG_PATH}"
    log_error "Available configs:"
    ls -1 infra/kubernetes/kind-*.yaml 2>/dev/null || true
    if [ -d "infra/kubernetes/extension" ]; then
        log_error "Extension configs:"
        find infra/kubernetes/extension -name "kind-*.yaml" 2>/dev/null | sed 's|infra/kubernetes/extension/kind-|extension/|' | sed 's|\.yaml||' || true
    fi
    exit 1
fi

# Show cluster configuration (only in debug mode)
if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
    log_section_start
    log_status "Kind Cluster Configuration"
    log_debug "  Cluster Name: ${CYAN}${CLUSTER_NAME}${NC}"
    log_debug "  Kubernetes Version: ${CYAN}${K8S_VERSION}${NC}"
    log_debug "  Configuration File: ${CYAN}${KIND_CONFIG_FILE}${NC}"
    log_section_end
fi

# Prepare data directories with correct permissions before cluster creation
log_debug "Preparing data directories..."
# Create both kubeconfig and storage directories to prevent root ownership
mkdir -p data/kubeconfig
mkdir -p data/storage

# Create Kind cluster with retry logic
log_info "Creating Kind cluster..."
if ! retry_with_backoff "Creating Kind cluster" \
    kind create cluster \
        --name "${CLUSTER_NAME}" \
        --config "${KIND_CONFIG_PATH}" \
        --image "kindest/node:${K8S_VERSION}" \
        --wait 300s; then
    exit 1
fi

# Export kubeconfig
log_debug "Setting up kubeconfig..."
# Use absolute path to avoid shell expansion issues in WSL
KUBECONFIG_FULL_PATH="$(realpath data/kubeconfig/config)"
kind export kubeconfig \
    --name "${CLUSTER_NAME}" \
    --kubeconfig "${KUBECONFIG_FULL_PATH}"

# Set up kubectl context
export KUBECONFIG="${KUBECONFIG_FULL_PATH}"

# Fix kubeconfig for CI environment (GitLab CI networking)
if [[ "${KIND_CONFIG}" == "ci" ]]; then
    log_debug "Applying CI-specific kubeconfig fixes for GitLab CI networking..."
    # Replace 0.0.0.0 and localhost with docker hostname for GitLab CI
    sed -i.bak -E -e "s/localhost|0\.0\.0\.0/docker/g" "${KUBECONFIG_FULL_PATH}"
    log_debug "Kubeconfig updated for GitLab CI docker-in-docker networking"
fi

# Wait for cluster to be ready with retry
log_debug "Waiting for cluster nodes to be ready..."
if ! retry_with_backoff "Waiting for nodes to be ready" \
    kubectl wait --for=condition=Ready nodes --all --timeout=300s; then
    exit 1
fi

# Show cluster status
log_debug "Cluster status:"
kubectl get nodes

# Setup add-ons if enabled (using host-installed kubectl/helm)
if [[ "${METALLB_ENABLED}" == "true" ]]; then
    log_info "Setting up MetalLB..."
    if [ -f "infra/scripts/setup-metallb.sh" ]; then
        KUBECONFIG="${KUBECONFIG_FULL_PATH}" ./infra/scripts/setup-metallb.sh || log_warn "MetalLB setup failed, continuing..."
    else
        log_warn "MetalLB setup script not found, skipping..."
    fi
fi

if [[ "${INGRESS_ENABLED}" == "true" ]]; then
    log_info "Setting up NGINX Ingress..."
    if [ -f "infra/scripts/setup-ingress.sh" ]; then
        KUBECONFIG="${KUBECONFIG_FULL_PATH}" ./infra/scripts/setup-ingress.sh || log_warn "Ingress setup failed, continuing..."
    else
        log_warn "Ingress setup script not found, skipping..."
    fi
fi

if [[ "${FLUX_ENABLED}" == "true" ]]; then
    log_info "Setting up Flux GitOps..."
    if [ -f "infra/scripts/setup-flux.sh" ]; then
        KUBECONFIG="${KUBECONFIG_FULL_PATH}" ./infra/scripts/setup-flux.sh || log_warn "Flux setup failed, continuing..."
    else
        log_warn "Flux setup script not found, skipping..."
    fi
fi

# Final cluster readiness check already shown above

# Clear trap on successful completion
trap - ERR

log_success "Kind cluster '${CLUSTER_NAME}' is ready!"
