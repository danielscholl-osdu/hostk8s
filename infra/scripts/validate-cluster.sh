#!/bin/bash
set -euo pipefail

# Cluster validation script - supports both simple and comprehensive validation
# Usage: ./validate-cluster.sh [--simple]

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

# Check for --simple flag
SIMPLE_MODE=false
if [[ "${1:-}" == "--simple" ]]; then
    SIMPLE_MODE=true
fi

# Source environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set defaults
CLUSTER_NAME=${CLUSTER_NAME:-dev-cluster}
METALLB_ENABLED=${METALLB_ENABLED:-false}
INGRESS_ENABLED=${INGRESS_ENABLED:-false}

# Set kubeconfig path
KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    error "Kubeconfig not found at $KUBECONFIG_PATH"
    error "Run ./infra/scripts/cluster-up.sh first"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

if [ "$SIMPLE_MODE" = true ]; then
    log "🧪 Running essential cluster validation..."
else
    log "Running comprehensive cluster validation for cluster '${CLUSTER_NAME}'..."
fi

# Test 1: Check cluster info
log "✓ Test 1: Checking cluster connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
    log "✅ Cluster API accessible"
else
    echo "❌ Cannot connect to cluster"
    exit 1
fi

# Test 2: Check all nodes are ready
log "✓ Test 2: Checking node status..."
node_status=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | sort -u)
if [[ "$node_status" == "Ready" ]]; then
    node_count=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
    log "✅ All $node_count nodes are ready"
else
    error "Some nodes are not ready"
    kubectl get nodes
    exit 1
fi

# Test 3: Check system pods
log "✓ Test 3: Checking system pods..."
not_running=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l | tr -d ' \n' || echo "0")
if [[ "$not_running" -eq 0 ]]; then
    log "✅ All system pods are running"
else
    warn "⚠ $not_running system pods are not running (this may be normal during startup)"
    if [ "$SIMPLE_MODE" = false ]; then
        kubectl get pods -n kube-system | grep -v "Running\|Completed" || true
    fi
fi

# Test 4: Check sample deployment (simple mode only)
if [ "$SIMPLE_MODE" = true ]; then
    log "✓ Test 4: Checking sample application..."
    if kubectl get deployment sample-app >/dev/null 2>&1; then
        ready_replicas=$(kubectl get deployment sample-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        desired_replicas=$(kubectl get deployment sample-app -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        if [[ "$ready_replicas" == "$desired_replicas" && "$ready_replicas" != "0" ]]; then
            log "✅ Sample application is running ($ready_replicas/$desired_replicas replicas)"
        else
            warn "⚠ Sample application not fully ready ($ready_replicas/$desired_replicas replicas)"
        fi
    else
        log "ℹ️ No sample application deployed"
    fi
    
    log "✅ Cluster validation completed successfully!"
    log ""
    log "Access your applications:"
    log "  • NodePort services: http://localhost:8080"
    log "  • kubectl get pods -o wide"
    log "  • kubectl get svc"
    exit 0
fi

# === COMPREHENSIVE MODE TESTS (beyond this point) ===

# Test 4: DNS resolution test
log "✓ Test 4: Testing DNS resolution..."
if kubectl run dns-test --image=busybox:1.28 --rm -i --restart=Never --quiet -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
    log "✅ DNS resolution working"
else
    warn "⚠ DNS resolution test failed"
fi

# Test 5: Create and delete a test pod
log "✓ Test 5: Testing pod creation and deletion..."
if kubectl run test-pod --image=busybox --rm -i --restart=Never --quiet -- echo "Pod creation test" >/dev/null 2>&1; then
    log "✅ Pod creation and deletion working"
else
    warn "⚠ Pod creation test failed"
fi

# Test 6: Service creation test
log "✓ Test 6: Testing service creation..."
kubectl create deployment test-service --image=nginx:alpine >/dev/null 2>&1 || true
kubectl expose deployment test-service --port=80 --target-port=80 >/dev/null 2>&1 || true
sleep 2
if kubectl get service test-service >/dev/null 2>&1; then
    log "✅ Service and deployment creation working"
    # Cleanup
    kubectl delete deployment test-service >/dev/null 2>&1 || true
    kubectl delete service test-service >/dev/null 2>&1 || true
else
    warn "⚠ Service creation test failed"
fi

# Test 7: Check if MetalLB is working (if enabled)
if [[ "${METALLB_ENABLED}" == "true" ]]; then
    log "✓ Test 7: Checking MetalLB LoadBalancer..."
    metallb_pods=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
    if [[ "$metallb_pods" -gt 0 ]]; then
        log "✅ MetalLB is running ($metallb_pods pods)"
    else
        warn "⚠ MetalLB pods not found or not running"
    fi
else
    log "ℹ️ Test 7: MetalLB not enabled, skipping LoadBalancer test"
fi

# Test 8: Check if Ingress is working (if enabled)
if [[ "${INGRESS_ENABLED}" == "true" ]]; then
    log "✓ Test 8: Checking NGINX Ingress..."
    ingress_pods=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
    if [[ "$ingress_pods" -gt 0 ]]; then
        log "✅ NGINX Ingress is running ($ingress_pods pods)"
    else
        warn "⚠ NGINX Ingress pods not found or not running"
    fi
else
    log "ℹ️ Test 8: NGINX Ingress not enabled, skipping"
fi

# Test 9: NodePort accessibility test
log "✓ Test 9: Testing NodePort service access..."
kubectl create deployment nodeport-test --image=nginx:alpine >/dev/null 2>&1 || true
kubectl expose deployment nodeport-test --type=NodePort --port=80 --target-port=80 >/dev/null 2>&1 || true
sleep 3
if kubectl get service nodeport-test >/dev/null 2>&1; then
    log "✅ NodePort service created successfully"
    # Cleanup
    kubectl delete deployment nodeport-test >/dev/null 2>&1 || true
    kubectl delete service nodeport-test >/dev/null 2>&1 || true
else
    warn "⚠ NodePort service creation failed"
fi

# Final status
log "Cluster validation completed!"
warnings=$(kubectl get events --field-selector type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "$warnings" -gt 5 ]]; then
    warn "Cluster has $warnings warning events, but this is usually normal"
fi

log "Cluster '${CLUSTER_NAME}' is ready for development workloads"
log ""
log "Quick start commands:"
log "  export KUBECONFIG=\$(pwd)/data/kubeconfig/config"
log "  kubectl get nodes"
log "  kubectl get pods -A"
log ""
log "Access services:"
log "  NodePort services: http://localhost:8080"