#!/bin/bash
# infra/scripts/utils.sh - Development utilities
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Source environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"

# Ensure cluster is running
if [ ! -f "$KUBECONFIG_PATH" ]; then
    warn "Cluster not found. Starting cluster..."
    ./infra/scripts/cluster-up.sh
fi

export KUBECONFIG="$KUBECONFIG_PATH"

# Simple status check
dev_status() {
    log "=== Cluster Status ==="
    kubectl get nodes
    echo
    
    log "=== System Health ==="
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded | \
        grep -v "^NAMESPACE" || log "✓ All pods running"
    echo
    
    log "=== Services ==="
    kubectl get svc -A -o wide | grep -v "ClusterIP.*<none>" || log "No external services"
}

# Focused log viewing
dev_logs() {
    local target=${1:-}
    
    if [ -z "$target" ]; then
        log "Recent cluster events:"
        kubectl get events --sort-by=.metadata.creationTimestamp -A | tail -10
        echo
        log "Usage: $0 logs <pod-name|deployment-name>"
        log "       $0 logs -l app=myapp"
        return
    fi
    
    # Try as pod first, then deployment
    if kubectl get pod "$target" >/dev/null 2>&1; then
        kubectl logs -f "$target" --tail=50
    elif kubectl get deployment "$target" >/dev/null 2>&1; then
        kubectl logs -f "deployment/$target" --tail=50
    else
        # Assume it's a label selector
        kubectl logs -f $target --tail=50
    fi
}

# Simple shell access
dev_shell() {
    local pod=${1:-}
    
    if [ -z "$pod" ]; then
        log "Creating debug pod..."
        kubectl run debug-$(date +%s) --image=busybox --rm -it --restart=Never -- /bin/sh
    else
        kubectl exec -it "$pod" -- /bin/sh 2>/dev/null || \
        kubectl exec -it "$pod" -- /bin/bash
    fi
}

# Port forwarding helper
dev_forward() {
    local service=${1:-}
    local port=${2:-8080}
    
    if [ -z "$service" ]; then
        log "Available services:"
        kubectl get svc
        return
    fi
    
    log "Forwarding $service to localhost:$port (Ctrl+C to stop)"
    kubectl port-forward "svc/$service" "$port:80"
}

# Development cleanup
dev_cleanup() {
    log "Cleaning up development resources..."
    
    # Remove debug pods
    kubectl delete pods -l "run" --field-selector=status.phase=Succeeded --ignore-not-found=true -q
    
    # Remove failed pods  
    kubectl delete pods --field-selector=status.phase=Failed --ignore-not-found=true -q
    
    log "✓ Cleanup complete"
}

# Quick test deployment (simple, no ingress complexity)
dev_deploy() {
    local image=${1:-nginx:alpine}
    local name=${2:-test-$(date +%s)}
    
    log "Deploying $image as $name..."
    
    kubectl create deployment "$name" --image="$image"
    kubectl expose deployment "$name" --port=80 --type=NodePort
    
    log "Waiting for deployment..."
    kubectl wait --for=condition=available --timeout=60s "deployment/$name"
    
    local nodeport=$(kubectl get svc "$name" -o jsonpath='{.spec.ports[0].nodePort}')
    
    log "✓ Deployed successfully"
    log "  Access: http://localhost:$nodeport"
    log "  Cleanup: kubectl delete deployment,service $name"
}

# Show helpful info
dev_info() {
    log "=== Quick Reference ==="
    echo "Cluster: $(kubectl config current-context)"
    echo "API: https://localhost:6443"
    echo "NodePort: http://localhost:8080"
    echo
    echo "Useful commands:"
    echo "  kubectl get pods"
    echo "  kubectl port-forward svc/myservice 8080:80"
    echo "  kubectl logs -f deployment/myapp"
}

# Main command handling
case "${1:-help}" in
    "status"|"s")
        dev_status
        ;;
    "logs"|"l")
        dev_logs "${2:-}"
        ;;
    "shell"|"sh")
        dev_shell "${2:-}"
        ;;
    "forward"|"f")
        dev_forward "${2:-}" "${3:-8080}"
        ;;
    "cleanup"|"clean")
        dev_cleanup
        ;;
    "deploy"|"d")
        dev_deploy "${2:-}" "${3:-}"
        ;;
    "info"|"i")
        dev_info
        ;;
    *)
        echo "OSDU-CI Development Tools (Simple)"
        echo
        echo "Commands:"
        echo "  status (s)           Show cluster health"
        echo "  logs (l) <target>    Show logs for pod/deployment/selector"
        echo "  shell (sh) [pod]     Open shell (creates debug pod if no target)"
        echo "  forward (f) <svc>    Port forward service to localhost"
        echo "  cleanup              Remove debug/failed pods"
        echo "  deploy (d) [image]   Quick test deployment"
        echo "  info (i)             Show cluster info and tips"
        echo
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 logs my-pod"
        echo "  $0 logs -l app=myapp"
        echo "  $0 shell"
        echo "  $0 forward my-service"
        echo "  $0 deploy redis:alpine"
        ;;
esac