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
- Use shared utilities from `common.sh` (bash) or `common.ps1` (PowerShell)
- Follow established logging and error handling patterns
- Maintain consistent function naming and structure

### 4. Cross-Platform Functional Parity
- Both `.sh` and `.ps1` implementations must provide identical user experience
- Platform-specific optimizations are encouraged (native package managers, tooling)
- Dual maintenance ensures optimal developer experience on each platform

## Script Structure Standards

### Required Header - Bash (.sh)
```bash
#!/bin/bash
set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source shared utilities
source "$(dirname "$0")/common.sh"
```

### Required Header - PowerShell (.ps1)
```powershell
# Error handling - equivalent to 'set -euo pipefail'
$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:Verbose'] = $false

# Disable debug mode to prevent environment variable exposure
$DebugPreference = "SilentlyContinue"

# Source shared utilities
. "$PSScriptRoot\common.ps1"
```

### Error Handling Patterns

#### ✅ DO - Proper Error Handling (Bash)
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

#### ✅ DO - Proper Error Handling (PowerShell)
```powershell
# Function with proper error handling
function Get-PodCountInNamespace {
    param([string]$Namespace)

    try {
        $output = kubectl get pods -n $Namespace --no-headers 2>$null
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to get pods in namespace $Namespace"
            return 1
        }

        $runningCount = ($output | Select-String "Running").Count
        return if ($runningCount) { $runningCount } else { 0 }
    }
    catch {
        Log-Error "Failed to get pods in namespace $Namespace: $_"
        return 1
    }
}
```

#### ❌ DON'T - Error Masking
```bash
# Bash: Avoid masking errors with || echo patterns
pod_count=$(kubectl get pods | grep -c Running || echo "0")  # BAD
```

```powershell
# PowerShell: Avoid masking errors with try-catch-all
try {
    $pod_count = kubectl get pods | Select-String "Running" | Measure-Object | Select-Object -ExpandProperty Count
} catch {
    $pod_count = 0  # BAD - masks real errors
}
```

### Logging Standards

#### Use Common Utility Functions

**Bash (common.sh):**
```bash
log_info "Starting cluster validation..."
log_warn "! System pods starting up, this is normal"
log_error "❌ Critical failure in cluster connectivity"
log_debug "Debug info (only shown when LOG_LEVEL=debug)"
```

**PowerShell (common.ps1):**
```powershell
Log-Info "Starting cluster validation..."
Log-Warn "! System pods starting up, this is normal"
Log-Error "❌ Critical failure in cluster connectivity"
Log-Debug "Debug info (only shown when LOG_LEVEL=debug)"
```

#### Status Indicators (Both Platforms)
- ✅ Success: `log_info "✅ Success message"` / `Log-Info "✅ Success message"`
- ! Warning: `log_warn "! Warning message"` / `Log-Warn "! Warning message"`
- ❌ Error: `log_error "❌ Error message"` / `Log-Error "❌ Error message"`
- ℹ️ Information: `log_info "ℹ️ Information message"` / `Log-Info "ℹ️ Information message"`
- ✓ Test Status: `log_info "✓ Test N: Description..."` / `Log-Info "✓ Test N: Description..."`

### Function Design Patterns

#### Validation Functions

**Bash:**
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

**PowerShell:**
```powershell
function Test-ResourceExists {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$Namespace = "default"
    )

    $result = kubectl get $ResourceType $ResourceName -n $Namespace 2>$null
    return $LASTEXITCODE -eq 0
}
```

#### Test Functions

**Bash:**
```bash
run_test_component_status() {
    log_info "✓ Test N: Checking component status..."

    if validate_component; then
        log_info "✅ Component is healthy"
        return 0
    else
        log_warn "! Component has issues"
        return 1
    fi
}
```

**PowerShell:**
```powershell
function Invoke-TestComponentStatus {
    Log-Info "✓ Test N: Checking component status..."

    if (Test-Component) {
        Log-Info "✅ Component is healthy"
        return 0
    } else {
        Log-Warn "! Component has issues"
        return 1
    }
}
```

## Environment and Configuration

### Environment Variable Handling

**Bash:**
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

**PowerShell:**
```powershell
# Source environment variables safely
if (Test-Path .env) {
    Get-Content .env | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
}

# Set defaults
$env:CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "dev-cluster" }
$env:COMPONENT_ENABLED = if ($env:COMPONENT_ENABLED) { $env:COMPONENT_ENABLED } else { "false" }
```

### KUBECONFIG Management

**Bash:**
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

**PowerShell:**
```powershell
# Auto-detect kubeconfig in scripts that need it
function Find-KubeConfig {
    if ($env:KUBECONFIG) {
        $Global:KUBECONFIG_PATH = $env:KUBECONFIG
    } elseif (Test-Path "$(Get-Location)/data/kubeconfig/config") {
        $Global:KUBECONFIG_PATH = "$(Get-Location)/data/kubeconfig/config"
    } else {
        throw "No kubeconfig found. Ensure cluster is running."
    }
}
```

## Testing and Validation Patterns

### Testing Philosophy

HostK8s scripts are designed for **direct execution testing** rather than formal unit testing frameworks. Each script can be run in isolation to validate functionality.

### Modular Test Structure

**Bash:**
```bash
# Separate test functions for different concerns
run_test_connectivity()     # Basic cluster access
run_test_system_health()    # Core Kubernetes components
run_test_addon_status()     # Optional components (Flux, MetalLB, etc.)
run_test_application_health() # User workloads
```

**PowerShell:**
```powershell
# PowerShell equivalents
function Invoke-ConnectivityTest { }     # Basic cluster access
function Invoke-SystemHealthTest { }     # Core Kubernetes components
function Invoke-AddonStatusTest { }      # Optional components
function Invoke-ApplicationHealthTest { } # User workloads
```

### Failure Tracking

**Bash:**
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
    log_warn "! $TEST_FAILURES warnings (may be normal during startup)"
fi
```

**PowerShell:**
```powershell
# Use failure counters for non-critical tests
$TEST_FAILURES = 0

if (!(Invoke-NonCriticalTest)) {
    $TEST_FAILURES++
}

# Report final status
if ($TEST_FAILURES -eq 0) {
    Log-Info "✅ All tests passed"
} else {
    Log-Warn "! $TEST_FAILURES warnings (may be normal during startup)"
}
```

### Cross-Platform Testing Validation

Both `.sh` and `.ps1` implementations must:
- Produce identical output formats
- Handle the same error conditions
- Support the same environment variables
- Return consistent exit codes

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

### Production Code Philosophy
- **Working code trumps theoretical improvements** - If scripts work reliably in production, changes need extraordinary justification
- **Complexity serves a purpose** - Apparent "complexity" often handles real-world deployment scenarios
- **Dual maintenance overhead** - Changes must be implemented and tested across both .sh and .ps1
- **Risk assessment** - Weigh benefits against potential for introducing bugs in working systems

## Security Practices

### Environment Variable Safety

**Bash:**
```bash
# Disable debug mode to prevent secret exposure
set +x

# Suppress output when sourcing environment files
source .env 2>/dev/null || true
```

**PowerShell:**
```powershell
# Disable debug mode to prevent secret exposure
$DebugPreference = "SilentlyContinue"

# Suppress output when sourcing environment files
try { . .env 2>$null } catch { }
```

### Input Validation

**Bash:**
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

**PowerShell:**
```powershell
function Test-InputValidation {
    param([string]$Input, [string]$Pattern)

    if ($Input -notmatch $Pattern) {
        Log-Error "Invalid input: $Input"
        return $false
    }
    return $true
}
```

## Cross-Platform Compatibility

HostK8s maintains dual script implementations (.sh/.ps1) to provide optimal platform integration while ensuring functional parity.

### Cross-Platform Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Functional Parity** | Both `.sh` and `.ps1` provide identical user experience |
| **Platform Optimization** | Use native package managers and tools per platform |
| **Consistent Interface** | Same Make commands work across all platforms |
| **Independent Maintenance** | Scripts can be optimized per platform without cross-platform compromise |

### Platform-Specific Operations

**Text Processing (sed equivalent):**

*Bash:*
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

*PowerShell:*
```powershell
# PowerShell uses different approach - no sed needed
function Update-FileContent {
    param([string]$Pattern, [string]$Replacement, [string]$FilePath)

    (Get-Content $FilePath) -replace $Pattern, $Replacement | Set-Content $FilePath
}
```

### Package Manager Integration

| Platform | Package Manager | Script Integration |
|----------|----------------|--------------------|
| **macOS** | brew | `brew install kind kubectl helm` |
| **Linux** | apt/yum/native | `apt-get install -y kind kubectl helm` |
| **Windows** | winget (preferred) | `winget install Kubernetes.kind Kubernetes.kubectl` |
| **Windows** | chocolatey (fallback) | `choco install kind kubernetes-kubectl helm` |

### Path Handling

**Bash:**
```bash
# Unix-style paths
KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"
SCRIPT_DIR="$(dirname "$0")"
```

**PowerShell:**
```powershell
# Windows-style paths with cross-platform support
$KUBECONFIG_PATH = "$(Get-Location)/data/kubeconfig/config"
$SCRIPT_DIR = $PSScriptRoot
```

### Environment Variable Sourcing

**Bash (.env handling):**
```bash
if [ -f .env ]; then
    set -a  # Enable allexport
    source .env
    set +a  # Disable allexport
fi
```

**PowerShell (.env handling):**
```powershell
if (Test-Path .env) {
    Get-Content .env | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
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

## Cross-Platform Maintenance Guidelines

### Functional Parity Checklist

When modifying scripts, ensure both `.sh` and `.ps1` implementations:
- [ ] Produce identical output formats
- [ ] Handle the same error conditions consistently
- [ ] Support identical environment variables
- [ ] Return consistent exit codes
- [ ] Follow platform-specific best practices

### Platform-Specific Optimizations

| Aspect | Bash Approach | PowerShell Approach |
|--------|---------------|--------------------|
| **Error Handling** | `set -euo pipefail` | `$ErrorActionPreference = "Stop"` |
| **Logging** | `echo -e` with colors | `Write-Host` with `-ForegroundColor` |
| **File Operations** | `sed`, `grep`, `awk` | `-replace`, `Select-String`, pipeline |
| **Package Managers** | `brew`, `apt`, `yum` | `winget`, `chocolatey` |
| **Path Handling** | `$(pwd)`, `$(dirname "$0")` | `$(Get-Location)`, `$PSScriptRoot` |

### Testing Both Implementations

```bash
# Test bash version
./infra/scripts/cluster-status.sh

# Test PowerShell version (Windows or cross-platform PowerShell)
pwsh ./infra/scripts/cluster-status.ps1
```

---

## Summary

These practices have evolved from real-world usage and optimization efforts. They prioritize:
1. **Reliability** - Scripts that work consistently across platforms
2. **Maintainability** - Clear, consistent patterns in both bash and PowerShell
3. **Safety** - Proper error handling and security practices
4. **Universality** - Tool-agnostic functionality with platform optimization
5. **Functional Parity** - Identical user experience regardless of platform

When in doubt, prefer explicit error handling over convenience, preserve complexity that handles real-world scenarios, and maintain functional parity between .sh and .ps1 implementations.
