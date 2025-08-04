#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Cluster validation script - supports both simple and comprehensive validation
# Usage: ./cluster-validate.sh [--simple]

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Validation helper functions
validate_kubectl_access() {
    kubectl cluster-info >/dev/null 2>&1
}

validate_namespace_exists() {
    local namespace="$1"
    kubectl get namespace "$namespace" >/dev/null 2>&1
}

get_pod_count_in_namespace() {
    local namespace="$1"
    local selector="${2:-}"
    local status_filter="${3:-Running}"

    local cmd="kubectl get pods -n $namespace --no-headers"
    if [[ -n "$selector" ]]; then
        cmd="$cmd -l $selector"
    fi

    # Count pods matching status filter, handle errors properly
    if ! output=$($cmd 2>/dev/null); then
        echo "ERROR: Failed to get pods in namespace $namespace" >&2
        return 1
    fi

    if [[ -z "$output" ]]; then
        echo "0"
        return 0
    fi

    echo "$output" | grep -c "$status_filter" || echo "0"
}

get_deployment_status() {
    local deployment="$1"
    local namespace="${2:-default}"

    if ! kubectl get deployment "$deployment" -n "$namespace" >/dev/null 2>&1; then
        echo "NOT_FOUND"
        return 1
    fi

    local ready_replicas desired_replicas
    ready_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    desired_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [[ "$ready_replicas" == "$desired_replicas" && "$ready_replicas" != "0" ]]; then
        echo "READY:$ready_replicas/$desired_replicas"
        return 0
    else
        echo "NOT_READY:$ready_replicas/$desired_replicas"
        return 1
    fi
}

validate_system_pods() {
    local namespace="${1:-kube-system}"

    if ! output=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null); then
        log_error "Failed to get pods in $namespace namespace"
        return 1
    fi

    if [[ -z "$output" ]]; then
        log_warn "No pods found in $namespace namespace"
        return 1
    fi

    local not_running_count
    not_running_count=$(echo "$output" | grep -cv "Running\|Completed" || echo "0")

    if [[ "$not_running_count" -eq 0 ]]; then
        return 0
    else
        log_warn "$not_running_count system pods are not running (this may be normal during startup)"
        return 1
    fi
}

# PR workflow integration (separate from cluster validation)
run_pr_workflow_test() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] PR-WORKFLOW-TEST:${NC} ✓ PR Workflow Test: Validating hybrid CI/CD integration..."

    if [ -n "${CI_COMMIT_REF_NAME:-}" ]; then
        echo -e "${GREEN}[$(date +'%H:%M:%S')] PR-WORKFLOW-TEST:${NC} Branch: ${CI_COMMIT_REF_NAME}"
        if [ "${CI_COMMIT_REF_NAME}" != "main" ]; then
            echo -e "${GREEN}[$(date +'%H:%M:%S')] PR-WORKFLOW-TEST:${NC} PR branch detected - This should trigger minimal GitHub Actions testing"
        else
            echo -e "${GREEN}[$(date +'%H:%M:%S')] PR-WORKFLOW-TEST:${NC} Main branch detected - This should trigger full GitHub Actions testing"
        fi
    else
        echo -e "${GREEN}[$(date +'%H:%M:%S')] PR-WORKFLOW-TEST:${NC} Local validation - CI variables not available"
    fi
}

# Standardized validation test functions
run_test_cluster_connectivity() {
    log_info "✓ Test 1: Checking cluster connectivity..."

    if validate_kubectl_access; then
        log_info "✅ Cluster API accessible"
        return 0
    else
        log_error "❌ Cannot connect to cluster"
        return 1
    fi
}

run_test_node_status() {
    log_info "✓ Test 2: Checking node status..."

    local node_status node_count
    if ! node_status=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | sort -u); then
        log_error "Failed to get node status"
        return 1
    fi

    if [[ "$node_status" == "Ready" ]]; then
        node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
        log_info "✅ All $node_count nodes are ready"
        return 0
    else
        log_error "Some nodes are not ready"
        kubectl get nodes
        return 1
    fi
}

run_test_system_pods() {
    log_info "✓ Test 3: Checking system pods..."

    if validate_system_pods "kube-system"; then
        log_info "✅ All system pods are running"
        return 0
    else
        # validate_system_pods already logged the warning
        return 1
    fi
}

run_test_sample_deployment() {
    local deployment_name="$1"
    local namespace="${2:-default}"

    log_info "✓ Test 5: Checking $deployment_name deployment..."

    local status
    status=$(get_deployment_status "$deployment_name" "$namespace")
    local exit_code=$?

    case "$status" in
        "NOT_FOUND")
            log_info "ℹ️ No $deployment_name deployment found"
            return 0  # Not an error in simple mode
            ;;
        "READY:"*)
            local replicas="${status#READY:}"
            log_info "✅ $deployment_name is running ($replicas replicas)"
            return 0
            ;;
        "NOT_READY:"*)
            local replicas="${status#NOT_READY:}"
            log_warn "⚠ $deployment_name not fully ready ($replicas replicas)"
            return 1
            ;;
        *)
            log_error "Failed to get $deployment_name status"
            return 1
            ;;
    esac
}

run_test_flux_status() {
    log_info "✓ Test 6: Checking Flux GitOps status..."

    if [[ "${FLUX_ENABLED:-false}" != "true" ]]; then
        log_info "ℹ️ Flux GitOps not enabled, skipping"
        return 0
    fi

    if ! validate_namespace_exists "flux-system"; then
        log_warn "⚠ Flux system namespace not found"
        return 1
    fi

    local flux_pods
    if ! flux_pods=$(get_pod_count_in_namespace "flux-system" "" "Running"); then
        log_warn "⚠ Failed to get Flux pod status"
        return 1
    fi

    if [[ "$flux_pods" -gt 0 ]]; then
        log_info "✅ Flux GitOps is running ($flux_pods pods)"

        # Check for demo application
        local demo_status
        demo_status=$(get_deployment_status "demo-app" "default")
        case "$demo_status" in
            "READY:"*)
                log_info "✅ GitOps demo application deployed successfully"
                ;;
            "NOT_FOUND")
                log_info "ℹ️ GitOps demo application not yet deployed (this is normal on first startup)"
                ;;
            *)
                log_info "ℹ️ GitOps demo application status: $demo_status"
                ;;
        esac
        return 0
    else
        log_warn "⚠ Flux GitOps pods not found or not running"
        return 1
    fi
}

run_test_metallb_status() {
    log_info "✓ Test 7: Checking MetalLB LoadBalancer..."

    if [[ "${METALLB_ENABLED}" != "true" ]]; then
        log_info "ℹ️ MetalLB not enabled, skipping LoadBalancer test"
        return 0
    fi

    if ! validate_namespace_exists "metallb-system"; then
        log_warn "⚠ MetalLB system namespace not found"
        return 1
    fi

    local metallb_pods
    if ! metallb_pods=$(get_pod_count_in_namespace "metallb-system" "app=metallb" "Running"); then
        log_warn "⚠ Failed to get MetalLB pod status"
        return 1
    fi

    if [[ "$metallb_pods" -gt 0 ]]; then
        log_info "✅ MetalLB is running ($metallb_pods pods)"
        return 0
    else
        log_warn "⚠ MetalLB pods not found or not running"
        return 1
    fi
}

run_test_ingress_status() {
    log_info "✓ Test 8: Checking NGINX Ingress..."

    if [[ "${INGRESS_ENABLED}" != "true" ]]; then
        log_info "ℹ️ NGINX Ingress not enabled, skipping"
        return 0
    fi

    if ! validate_namespace_exists "ingress-nginx"; then
        log_warn "⚠ NGINX Ingress namespace not found"
        return 1
    fi

    local ingress_pods
    if ! ingress_pods=$(get_pod_count_in_namespace "ingress-nginx" "app.kubernetes.io/name=ingress-nginx" "Running"); then
        log_warn "⚠ Failed to get NGINX Ingress pod status"
        return 1
    fi

    if [[ "$ingress_pods" -gt 0 ]]; then
        log_info "✅ NGINX Ingress is running ($ingress_pods pods)"
        return 0
    else
        log_warn "⚠ NGINX Ingress pods not found or not running"
        return 1
    fi
}

run_test_ingress_connectivity() {
    log_info "✓ Test 9: Testing ingress accessibility..."

    if [[ "${INGRESS_ENABLED:-false}" != "true" ]]; then
        log_info "ℹ️ Ingress not enabled, skipping accessibility test"
        return 0
    fi

    if curl -f -s --connect-timeout 5 http://localhost:8080 >/dev/null 2>&1; then
        log_info "✅ Ingress accessible at http://localhost:8080"
        return 0
    else
        log_warn "⚠ Ingress not accessible at http://localhost:8080 (may need time to start)"
        return 1
    fi
}


# Check for --simple flag
SIMPLE_MODE=false
if [[ "${1:-}" == "--simple" ]]; then
    SIMPLE_MODE=true
fi

# Source environment variables (suppress output to prevent secret exposure)
if [ -f .env ]; then
    set -a  # Enable allexport mode
    source .env
    set +a  # Disable allexport mode
fi

# Set defaults
CLUSTER_NAME=${CLUSTER_NAME:-dev-cluster}
METALLB_ENABLED=${METALLB_ENABLED:-false}
INGRESS_ENABLED=${INGRESS_ENABLED:-false}

# Set kubeconfig path
KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    log_error "Kubeconfig not found at $KUBECONFIG_PATH"
    log_error "Run ./infra/scripts/cluster-up.sh first"
    exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

if [ "$SIMPLE_MODE" = true ]; then
    log_info "🧪 Running essential cluster validation..."
else
    log_info "Running comprehensive cluster validation for cluster '${CLUSTER_NAME}'..."
fi

# Run core validation tests
TEST_FAILURES=0

# Test 1: Cluster connectivity
if ! run_test_cluster_connectivity; then
    log_error "Cluster connectivity test failed"
    exit 1
fi

# Test 2: Node status
if ! run_test_node_status; then
    log_error "Node status test failed"
    exit 1
fi

# Test 3: System pods
if ! run_test_system_pods; then
    ((TEST_FAILURES++))
fi

# Test 4: PR workflow validation test (separate from cluster validation)
run_pr_workflow_test

# Test 5: Sample application deployment (simple mode only)
if [ "$SIMPLE_MODE" = true ]; then
    if ! run_test_sample_deployment "sample-app" "default"; then
        ((TEST_FAILURES++))
    fi

    # Report simple mode results
    if [ "$TEST_FAILURES" -eq 0 ]; then
        log_info "✅ Essential cluster validation completed successfully!"
    else
        log_warn "⚠ Essential cluster validation completed with $TEST_FAILURES warnings"
    fi

    log_info ""
    log_info "Access your applications:"
    log_info "  • NodePort services: http://localhost:8080"
    log_info "  • kubectl get pods -o wide"
    log_info "  • kubectl get svc"
    exit 0
fi

# === COMPREHENSIVE MODE TESTS (beyond this point) ===

# Test 6: Flux GitOps status
if ! run_test_flux_status; then
    ((TEST_FAILURES++))
fi

# Test 7: MetalLB LoadBalancer
if ! run_test_metallb_status; then
    ((TEST_FAILURES++))
fi

# Test 8: NGINX Ingress
if ! run_test_ingress_status; then
    ((TEST_FAILURES++))
fi

# Test 9: Ingress connectivity
if ! run_test_ingress_connectivity; then
    ((TEST_FAILURES++))
fi


# Final status report
if [ "$TEST_FAILURES" -eq 0 ]; then
    log_info "✅ Comprehensive cluster validation completed successfully!"
else
    log_warn "⚠ Comprehensive cluster validation completed with $TEST_FAILURES warnings"
fi

# Check for excessive warning events
warnings=$(kubectl get events --field-selector type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [[ "$warnings" -gt 5 ]]; then
    log_warn "Cluster has $warnings warning events, but this is usually normal"
fi

log_info "Cluster '${CLUSTER_NAME}' is ready for development workloads"
log_info ""
log_info "Quick start commands:"
log_info "  export KUBECONFIG=\$(pwd)/data/kubeconfig/config"
log_info "  kubectl get nodes"
log_info "  kubectl get pods -A"
log_info ""
log_info "Access services:"
log_info "  NodePort services: http://localhost:8080"
