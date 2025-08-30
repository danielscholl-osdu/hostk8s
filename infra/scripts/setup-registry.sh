#!/bin/bash
set -euo pipefail

# Setup Container Registry add-on for HostK8s cluster
# Docker container approach following OpenFaaS/Kind pattern

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Registry configuration
REGISTRY_NAME='hostk8s-registry'
REGISTRY_PORT='5002'  # Use 5002 to avoid conflict with Kind NodePort on 5001
REGISTRY_INTERNAL_PORT='5000'

# Setting up Container Registry
log_info "[Registry] Setting up Container Registry add-on (Docker container)..."

# Validate Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "[Registry] ❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Validate cluster is running
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "[Registry] ❌ Cluster is not ready. Ensure cluster is started first."
    exit 1
fi

# Create host directory for registry storage if it doesn't exist
registry_data_dir="${PWD}/data/storage/registry"
if [ ! -d "$registry_data_dir" ]; then
    log_info "[Registry] Creating registry storage directory..."
    mkdir -p "$registry_data_dir"
fi

# Ensure registry docker subdirectory exists (required by registry for storage)
if [ ! -d "$registry_data_dir/docker" ]; then
    log_info "[Registry] Creating registry docker storage subdirectory..."
    mkdir -p "$registry_data_dir/docker"
fi

# Create registry config file if it doesn't exist
registry_config_file="${PWD}/data/registry-config.yml"
if [ ! -f "$registry_config_file" ]; then
    log_info "[Registry] Creating registry configuration file..."
    cat > "$registry_config_file" << 'EOF'
version: 0.1
log:
  fields:
    service: registry
storage:
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
EOF
fi

# Function to setup containerd configuration on Kind nodes
setup_containerd_config() {
    local node="$1"
    log_info "[Registry] Configuring containerd on node: $node"

    # Create containerd registry config directory
    docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:${REGISTRY_INTERNAL_PORT}"

    # Create hosts.toml configuration
    docker exec "$node" sh -c "cat > /etc/containerd/certs.d/localhost:${REGISTRY_INTERNAL_PORT}/hosts.toml << 'EOF'
server = \"http://${REGISTRY_NAME}:${REGISTRY_INTERNAL_PORT}\"

[host.\"http://${REGISTRY_NAME}:${REGISTRY_INTERNAL_PORT}\"]
  capabilities = [\"pull\", \"resolve\"]
  skip_verify = true
EOF"

    # Note: Kind config should already have config_path set, so hosts.toml should work without restart
    # Only modify containerd config if absolutely necessary
    if ! docker exec "$node" grep -q "config_path.*certs.d" /etc/containerd/config.toml 2>/dev/null; then
        log_warn "[Registry] Warning: config_path not found in containerd config"
        log_warn "[Registry] Registry may not work properly without containerd reconfiguration"
        # Skip the restart to avoid node disruption - Kind should have config_path already
    else
        log_info "[Registry] containerd config_path already configured"
    fi
}

# Check if registry container already exists and is running
if docker inspect "${REGISTRY_NAME}" >/dev/null 2>&1; then
    container_status=$(docker inspect -f '{{.State.Status}}' "${REGISTRY_NAME}")
    if [ "$container_status" = "running" ]; then
        log_info "[Registry] ✅ Container Registry already running"

        # Verify network connectivity
        if docker network inspect kind | grep -q "${REGISTRY_NAME}"; then
            log_info "[Registry] Registry container connected to Kind network"
        else
            log_info "[Registry] Connecting registry to Kind network..."
            docker network connect "kind" "${REGISTRY_NAME}"
        fi

        # Skip container creation but continue with UI deployment and configuration
        skip_container_creation=true
    else
        log_info "[Registry] Registry container exists but not running ($container_status)"
        log_info "[Registry] Removing old container..."
        docker rm -f "${REGISTRY_NAME}" 2>/dev/null || true
    fi
fi

# Create registry container (if not skipped)
if [ "${skip_container_creation:-false}" != "true" ]; then
    log_info "[Registry] Creating Container Registry container..."
    docker run \
      -d --restart=always \
      -p "127.0.0.1:${REGISTRY_PORT}:${REGISTRY_INTERNAL_PORT}" \
      -v "${registry_data_dir}:/var/lib/registry" \
      -v "${registry_config_file}:/etc/docker/registry/config.yml" \
      --name "${REGISTRY_NAME}" \
      registry:2

    # Connect registry to Kind network
    log_info "[Registry] Connecting registry to Kind network..."
    docker network connect "kind" "${REGISTRY_NAME}"
fi

# Configure containerd on all Kind nodes
log_info "[Registry] Configuring containerd on Kind cluster nodes..."
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
    setup_containerd_config "$node"
done

# Deploy registry UI (conditional on NGINX ingress)
registry_ui_deployed=false
if kubectl get ingressclass nginx >/dev/null 2>&1; then
    log_info "[Registry] NGINX Ingress detected, installing Registry UI..."

    # Note: hostk8s namespace is created during cluster startup

    if kubectl apply -f "${PWD}/infra/manifests/registry-ui.yaml" 2>/dev/null; then
        registry_ui_deployed=true

        # Wait for registry UI to be ready
        log_info "[Registry] Waiting for Container Registry UI to be ready..."
        kubectl wait --namespace hostk8s --for=condition=ready pod --selector=app=registry-ui --timeout=120s >/dev/null 2>&1 || true
    fi
else
    log_info "[Registry] NGINX Ingress not available - Registry UI skipped"
fi

# Test registry health
log_info "[Registry] Testing registry connectivity..."
max_attempts=10
attempt=1
while [ $attempt -le $max_attempts ]; do
    if curl -f http://localhost:${REGISTRY_PORT}/v2/ >/dev/null 2>&1; then
        break
    fi

    if [ $attempt -eq $max_attempts ]; then
        log_error "[Registry] ❌ Registry health check failed"
        exit 1
    fi

    sleep 3
    attempt=$((attempt + 1))
done

# Create local registry hosting ConfigMap (Kubernetes standard)
kubectl apply -f - <<EOF || true
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

log_info "[Registry] ✅ Container Registry setup complete"
log_info "[Registry] Access registry API at http://localhost:${REGISTRY_PORT}"
if [ "$registry_ui_deployed" = true ]; then
    log_info "[Registry] Web UI available at http://registry.localhost:8080"
fi
