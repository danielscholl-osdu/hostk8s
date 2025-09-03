#!/bin/bash
set -euo pipefail
set +x  # Prevent secret exposure

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Custom logging prefix for MetalLB addon
log_metallb() {
    log_info "[MetalLB] $*"
}

log_metallb_warn() {
    log_warn "[MetalLB] $*"
}

log_metallb_error() {
    log_error "[MetalLB] $*"
}

# Function for error handling
error_exit() {
    log_metallb_error "$1"
    exit 1
}

# Auto-detect execution environment and set kubeconfig path
detect_kubeconfig() {
    if [ -n "${KUBECONFIG:-}" ]; then
        KUBECONFIG_PATH="${KUBECONFIG}"
        log_metallb "Using KUBECONFIG environment variable: $KUBECONFIG_PATH"
    elif [ -f "/kubeconfig/config" ]; then
        KUBECONFIG_PATH="/kubeconfig/config"  # Container mode
        log_metallb "Using container kubeconfig: $KUBECONFIG_PATH"
    elif [ -f "${PWD}/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="${PWD}/data/kubeconfig/config"  # Host mode
        log_metallb "Using host-mode kubeconfig: $KUBECONFIG_PATH"
    else
        error_exit "No kubeconfig found. Ensure cluster is running."
    fi
}

detect_kubeconfig

log_metallb "Setting up MetalLB LoadBalancer..."

# Check if MetalLB is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace hostk8s >/dev/null 2>&1; then
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get deployment speaker -n hostk8s >/dev/null 2>&1; then
        log_metallb "MetalLB already installed, checking if running..."
        if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n hostk8s -l app=metallb | grep -q Running; then
            log_metallb "MetalLB appears to already be running"
            # Skip installation but continue with configuration
            skip_metallb_creation=true
        fi
    fi
fi

# Install MetalLB (if not skipped)
if [ "${skip_metallb_creation:-false}" != "true" ]; then
    log_metallb "Installing MetalLB..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "${PWD}/infra/manifests/metallb.yaml" || error_exit "Failed to install MetalLB"
fi

# Wait for MetalLB pods to be ready
log_metallb "Waiting for MetalLB pods to be ready..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=ready pod -l app=metallb -n hostk8s --timeout=300s || error_exit "MetalLB pods failed to become ready"

# Get Docker network subnet for MetalLB IP pool
log_metallb "Detecting Docker network subnet..."
# Look specifically for IPv4 subnet, fallback to default if not found
DOCKER_SUBNET=$(docker network inspect kind | jq -r '.[0].IPAM.Config[] | select(.Subnet | contains(".")) | .Subnet' 2>/dev/null | head -1)
if [ -z "$DOCKER_SUBNET" ] || [ "$DOCKER_SUBNET" = "null" ]; then
    DOCKER_SUBNET="172.18.0.0/16"
    log_metallb "Could not detect IPv4 subnet, using default: $DOCKER_SUBNET"
else
    log_metallb "Using Docker subnet: $DOCKER_SUBNET"
fi

# Extract network prefix and create IP pool range
NETWORK_PREFIX=$(echo "$DOCKER_SUBNET" | cut -d'/' -f1 | cut -d'.' -f1-2)
IP_POOL_START="${NETWORK_PREFIX}.200.200"
IP_POOL_END="${NETWORK_PREFIX}.200.250"

log_metallb "Configuring MetalLB IP pool: $IP_POOL_START-$IP_POOL_END"

# Create MetalLB IP address pool configuration
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - <<EOF || error_exit "Failed to configure MetalLB IP pool"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: hostk8s
spec:
  addresses:
  - $IP_POOL_START-$IP_POOL_END
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: hostk8s
spec:
  ipAddressPools:
  - kind-pool
EOF

# Test MetalLB by creating a test service
log_metallb "Testing MetalLB with a test service..."
cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log_metallb "WARNING: Failed to create test service"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metallb-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: metallb-test
  template:
    metadata:
      labels:
        app: metallb-test
    spec:
      containers:
      - name: nginx
        image: mcr.microsoft.com/azurelinux/base/nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: metallb-test
  namespace: default
spec:
  selector:
    app: metallb-test
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

# Wait for LoadBalancer IP assignment
log_metallb "Waiting for LoadBalancer IP assignment..."
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get svc metallb-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        log_metallb "LoadBalancer IP assigned: $EXTERNAL_IP"
        log_metallb "Testing connectivity to $EXTERNAL_IP..."
        if curl -s --connect-timeout 5 "http://$EXTERNAL_IP" >/dev/null; then
            log_metallb "MetalLB test successful!"
        else
            log_metallb "WARNING: Could not connect to LoadBalancer IP, but IP was assigned"
        fi
        break
    fi
    log_metallb "Waiting for LoadBalancer IP... (attempt $i/30)"
    sleep 5
done

if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
    log_metallb "WARNING: No LoadBalancer IP was assigned after 150 seconds"
else
    log_metallb "MetalLB setup completed successfully"
fi

# Clean up test service
log_metallb "Cleaning up test service..."
kubectl --kubeconfig="$KUBECONFIG_PATH" delete deployment,service metallb-test --ignore-not-found=true

log_metallb "MetalLB setup complete"
