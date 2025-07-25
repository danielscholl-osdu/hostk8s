#!/bin/bash
set -euo pipefail

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [MetalLB] $*"
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

detect_kubeconfig

log "Setting up MetalLB LoadBalancer..."

# Check if MetalLB is already installed
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace metallb-system >/dev/null 2>&1; then
    log "MetalLB namespace already exists, checking if installation is complete..."
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n metallb-system -l app=metallb | grep -q Running; then
        log "MetalLB appears to already be running"
        exit 0
    fi
fi

# Install MetalLB
log "Installing MetalLB..."
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml || error_exit "Failed to install MetalLB"

# Wait for MetalLB pods to be ready
log "Waiting for MetalLB pods to be ready..."
kubectl --kubeconfig="$KUBECONFIG_PATH" wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=300s || error_exit "MetalLB pods failed to become ready"

# Get Docker network subnet for MetalLB IP pool
log "Detecting Docker network subnet..."
# Look specifically for IPv4 subnet, fallback to default if not found
DOCKER_SUBNET=$(docker network inspect kind | jq -r '.[0].IPAM.Config[] | select(.Subnet | contains(".")) | .Subnet' 2>/dev/null | head -1)
if [ -z "$DOCKER_SUBNET" ] || [ "$DOCKER_SUBNET" = "null" ]; then
    DOCKER_SUBNET="172.18.0.0/16"
    log "Could not detect IPv4 subnet, using default: $DOCKER_SUBNET"
else
    log "Using Docker subnet: $DOCKER_SUBNET"
fi

# Extract network prefix and create IP pool range
NETWORK_PREFIX=$(echo "$DOCKER_SUBNET" | cut -d'/' -f1 | cut -d'.' -f1-2)
IP_POOL_START="${NETWORK_PREFIX}.255.200"
IP_POOL_END="${NETWORK_PREFIX}.255.250"

log "Configuring MetalLB IP pool: $IP_POOL_START-$IP_POOL_END"

# Create MetalLB IP address pool configuration
kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - <<EOF || error_exit "Failed to configure MetalLB IP pool"
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_POOL_START-$IP_POOL_END
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - kind-pool
EOF

# Test MetalLB by creating a test service
log "Testing MetalLB with a test service..."
cat <<EOF | kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f - || log "WARNING: Failed to create test service"
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
log "Waiting for LoadBalancer IP assignment..."
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get svc metallb-test -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        log "LoadBalancer IP assigned: $EXTERNAL_IP"
        log "Testing connectivity to $EXTERNAL_IP..."
        if curl -s --connect-timeout 5 "http://$EXTERNAL_IP" >/dev/null; then
            log "MetalLB test successful!"
        else
            log "WARNING: Could not connect to LoadBalancer IP, but IP was assigned"
        fi
        break
    fi
    log "Waiting for LoadBalancer IP... (attempt $i/30)"
    sleep 5
done

if [ -z "$EXTERNAL_IP" ] || [ "$EXTERNAL_IP" = "null" ]; then
    log "WARNING: No LoadBalancer IP was assigned after 150 seconds"
else
    log "MetalLB setup completed successfully"
fi

# Clean up test service
log "Cleaning up test service..."
kubectl --kubeconfig="$KUBECONFIG_PATH" delete deployment,service metallb-test --ignore-not-found=true

log "MetalLB setup complete"