# HostK8s Scripts - Best Practices and Guidelines

This document establishes coding standards and best practices for HostK8s infrastructure scripts, derived from optimization work and production experience.

## Core Principles

### 1. Tool Agnostic
- Scripts must work regardless of development tools (editors, AI assistants, etc.)
- No dependencies on Claude Code, GitHub Copilot, or other external development tools
- Focus purely on Kubernetes cluster functionality

### 2. Reliability Over Convenience
- Prefer explicit error handling over silent failures
- Complex logic exists to handle real-world deployment scenarios
- Don't optimize away necessary complexity in networking/infrastructure setup

### 3. Consistent Patterns
- Use shared utilities from `common.sh`
- Follow established logging and error handling patterns
- Maintain consistent function naming and structure

## Script Structure Standards

### Required Header
```bash
#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source shared utilities
source "$(dirname "$0")/common.sh"
```

### Error Handling Patterns

#### ✅ DO - Proper Error Handling
```bash
# Function with proper error handling
get_pod_count_in_namespace() {
    local namespace="$1"

    if ! output=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null); then
        log_error "Failed to get pods in namespace $namespace"
        return 1
    fi

    echo "$output" | grep -c "Running" || echo "0"
}
```

#### ❌ DON'T - Error Masking
```bash
# Avoid masking errors with || echo patterns
pod_count=$(kubectl get pods | grep -c Running || echo "0")  # BAD
```

### Logging Standards

#### Use common.sh Functions
```bash
log_info "Starting cluster validation..."
log_warn "⚠ System pods starting up, this is normal"
log_error "❌ Critical failure in cluster connectivity"
log_debug "Debug info (only shown when LOG_LEVEL=debug)"
```

#### Status Indicators
- ✅ `log_info "✅ Success message"`
- ⚠️ `log_warn "⚠ Warning message"`
- ❌ `log_error "❌ Error message"`
- ℹ️ `log_info "ℹ️ Information message"`
- ✓ `log_info "✓ Test N: Description..."`

### Function Design Patterns

#### Validation Functions
```bash
validate_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-default}"

    if ! kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}
```

#### Test Functions
```bash
run_test_component_status() {
    log_info "✓ Test N: Checking component status..."

    if validate_component; then
        log_info "✅ Component is healthy"
        return 0
    else
        log_warn "⚠ Component has issues"
        return 1
    fi
}
```

## Environment and Configuration

### Environment Variable Handling
```bash
# Source environment variables safely
if [ -f .env ]; then
    set -a  # Enable allexport mode
    source .env
    set +a  # Disable allexport mode
fi

# Set defaults
CLUSTER_NAME=${CLUSTER_NAME:-dev-cluster}
COMPONENT_ENABLED=${COMPONENT_ENABLED:-false}
```

### KUBECONFIG Management
```bash
# Auto-detect kubeconfig in scripts that need it
detect_kubeconfig() {
    if [ -n "${KUBECONFIG:-}" ]; then
        KUBECONFIG_PATH="${KUBECONFIG}"
    elif [ -f "$(pwd)/data/kubeconfig/config" ]; then
        KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"
    else
        error_exit "No kubeconfig found. Ensure cluster is running."
    fi
}
```

## Testing and Validation Patterns

### Modular Test Structure
```bash
# Separate test functions for different concerns
run_test_connectivity()     # Basic cluster access
run_test_system_health()    # Core Kubernetes components
run_test_addon_status()     # Optional components (Flux, MetalLB, etc.)
run_test_application_health() # User workloads
```

### Failure Tracking
```bash
# Use failure counters for non-critical tests
TEST_FAILURES=0

if ! run_non_critical_test; then
    ((TEST_FAILURES++))
fi

# Report final status
if [ "$TEST_FAILURES" -eq 0 ]; then
    log_info "✅ All tests passed"
else
    log_warn "⚠ $TEST_FAILURES warnings (may be normal during startup)"
fi
```

## What NOT to Change

### Preserve Necessary Complexity
- **Network detection logic**: Docker network configuration varies significantly
- **Service patching operations**: Kubernetes networking requires specific configurations
- **CI environment handling**: Real environment differences require different approaches
- **Retry logic with backoff**: External services have timing dependencies

### Don't Over-Optimize
- Scripts that work reliably in production should not be refactored for style alone
- Complex conditional logic often handles real-world edge cases
- Error handling that seems verbose may be preventing subtle bugs

## Security Practices

### Environment Variable Safety
```bash
# Disable debug mode to prevent secret exposure
set +x

# Suppress output when sourcing environment files
source .env 2>/dev/null || true
```

### Input Validation
```bash
validate_input() {
    local input="$1"
    local pattern="$2"

    if [[ ! "$input" =~ $pattern ]]; then
        log_error "Invalid input: $input"
        return 1
    fi
}
```

## Cross-Platform Compatibility

### Platform-Specific Operations
```bash
# Use helper functions for platform differences
cross_platform_sed_inplace() {
    local pattern="$1"
    local file="$2"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}
```

## Documentation Standards

### Function Documentation
```bash
# Brief description of what the function does
# Parameters: $1 = description, $2 = optional description
# Returns: 0 on success, 1 on failure
function_name() {
    local required_param="$1"
    local optional_param="${2:-default_value}"

    # Implementation
}
```

### Script Purpose
Each script should have a clear comment block at the top describing:
- What the script does
- When it should be used
- What it requires to run successfully
- What it produces or changes

## Common Patterns to Follow

### Resource Waiting
```bash
# Wait with timeout and proper error handling
kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s || {
    log_error "Pods failed to become ready"
    kubectl get pods -l app=myapp  # Show current state
    return 1
}
```

### Conditional Component Handling
```bash
# Check if component is enabled before testing
if [[ "${COMPONENT_ENABLED:-false}" == "true" ]]; then
    test_component
else
    log_info "ℹ️ Component not enabled, skipping"
fi
```

---

## Summary

These practices have evolved from real-world usage and optimization efforts. They prioritize:
1. **Reliability** - Scripts that work consistently
2. **Maintainability** - Clear, consistent patterns
3. **Safety** - Proper error handling and security practices
4. **Universality** - Tool-agnostic functionality

When in doubt, prefer explicit error handling over convenience, and preserve complexity that handles real-world scenarios.
