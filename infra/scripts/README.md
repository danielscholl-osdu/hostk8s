# HostK8s Scripts - Essential Guidelines

Essential patterns and gotchas for HostK8s cross-platform script development.

## Core Principles

1. **Cross-Platform Functional Parity**: Both `.sh` and `.ps1` must provide identical user experience
2. **Reliability Over Convenience**: Prefer explicit error handling over silent failures
3. **Production Code First**: Working scripts trump theoretical improvements
4. **Tool Agnostic**: No dependencies on specific development tools

## Required Script Headers

### Bash (.sh)
```bash
#!/bin/bash
set -euo pipefail
set +x  # Prevent secret exposure
source "$(dirname "$0")/common.sh"
```

### PowerShell (.ps1)
```powershell
$ErrorActionPreference = "Stop"
$DebugPreference = "SilentlyContinue"  # Prevent secret exposure
. "$PSScriptRoot\common.ps1"
```

## Critical Cross-Platform Gotchas

### PowerShell External Command Variable Expansion

**⚠️ Most Common PowerShell Bug**: External commands with complex arguments fail silently.

**❌ This Often Fails:**
```powershell
$labelSelector = "hostk8s.application=api"
$services = kubectl get services -l $labelSelector --no-headers
# Result: Empty (fails silently due to argument parsing)
```

**✅ Use This Instead:**
```powershell
$labelSelector = "hostk8s.application=api"
$cmd = "kubectl get services -l `"$labelSelector`" --no-headers 2>`$null"
$services = Invoke-Expression $cmd
# Result: Works correctly
```

**When to Watch For:**
- kubectl commands with label selectors (`-l key=value`)
- Any external command with `key=value` arguments
- Special characters in arguments (dots, slashes, etc.)
- Cases where bash works but PowerShell returns empty

### Error Handling Patterns

**✅ Proper Error Handling:**
```bash
# Bash
if ! output=$(kubectl get pods 2>/dev/null); then
    log_error "Failed to get pods"
    return 1
fi
```

```powershell
# PowerShell
try {
    $output = kubectl get pods 2>$null
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to get pods"
        return 1
    }
} catch {
    Log-Error "Failed to get pods: $_"
    return 1
}
```

**❌ Error Masking (Avoid):**
```bash
# Bad - masks real errors
pod_count=$(kubectl get pods | grep -c Running || echo "0")
```

## Logging Standards

Use common utility functions consistently:

```bash
# Bash
log_info "✅ Success message"
log_warn "! Warning message"
log_error "❌ Error message"
```

```powershell
# PowerShell
Log-Info "✅ Success message"
Log-Warn "! Warning message"
Log-Error "❌ Error message"
```

## Platform-Specific Patterns

### Text Processing
```bash
# Bash: sed
sed -i 's/old/new/g' file.txt
```

```powershell
# PowerShell: -replace
(Get-Content file.txt) -replace 'old', 'new' | Set-Content file.txt
```

### Path Handling
```bash
# Bash
SCRIPT_DIR="$(dirname "$0")"
KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"
```

```powershell
# PowerShell
$SCRIPT_DIR = $PSScriptRoot
$KUBECONFIG_PATH = "$(Get-Location)/data/kubeconfig/config"
```

## What NOT to Change

### Preserve Production Complexity
- **Network detection logic**: Handles Docker platform variations
- **Retry logic with backoff**: External services have timing dependencies
- **Complex conditional logic**: Often handles real-world edge cases

### Production Code Philosophy
- **Working code trumps style** - Don't refactor stable production scripts
- **Complexity serves a purpose** - Handles real deployment scenarios
- **Dual maintenance cost** - Changes need both .sh and .ps1 implementation

## Environment & Configuration

### Environment Variables
```bash
# Bash
if [ -f .env ]; then
    set -a; source .env; set +a
fi
CLUSTER_NAME=${CLUSTER_NAME:-dev-cluster}
```

```powershell
# PowerShell
if (Test-Path .env) {
    Get-Content .env | Where-Object { $_ -match '^[^#].*=' } | ForEach-Object {
        $key, $value = $_ -split '=', 2
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}
$env:CLUSTER_NAME = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "dev-cluster" }
```

## Testing Patterns

### Direct Execution Testing
Scripts are designed for direct execution rather than formal unit testing:

```bash
# Test functions separately
run_test_connectivity()      # Basic cluster access
run_test_system_health()     # Core components
run_test_addon_status()      # Optional components
```

### Failure Tracking
```bash
# Non-critical test failure counting
TEST_FAILURES=0
if ! run_non_critical_test; then
    ((TEST_FAILURES++))
fi

if [ "$TEST_FAILURES" -eq 0 ]; then
    log_info "✅ All tests passed"
else
    log_warn "! $TEST_FAILURES warnings (normal during startup)"
fi
```

## Cross-Platform Maintenance

### Functional Parity Checklist
Both `.sh` and `.ps1` implementations must:
- [ ] Produce identical output formats
- [ ] Handle same error conditions consistently
- [ ] Support identical environment variables
- [ ] Return consistent exit codes

### Testing Both Platforms
```bash
# Test both implementations
./infra/scripts/cluster-status.sh
pwsh ./infra/scripts/cluster-status.ps1
```

## Package Managers

| Platform | Preferred | Command Example |
|----------|-----------|-----------------|
| **macOS** | brew | `brew install kind kubectl` |
| **Linux** | apt/yum | `apt-get install -y kind kubectl` |
| **Windows** | winget | `winget install Kubernetes.kind` |

---

## GitOps Sync Patterns

### Stack-Aware Sync (New Feature)
```bash
# Bash
./flux-sync.sh --stack sample    # Sync source + sample stack
```

```powershell
# PowerShell
./flux-sync.ps1 --stack sample   # Sync source + sample stack
```

**Implementation Notes:**
- Stack sync combines `flux reconcile source git flux-system` + `flux reconcile kustomization bootstrap-stack --with-source`
- Solves dependency chain deadlocks where components get stuck on different Git revisions
- Both .sh and .ps1 implementations must handle the `--stack` parameter identically

### Make Integration
```bash
make sync sample    # Calls flux-sync.sh --stack sample
make sync          # Syncs all sources + stack kustomizations
```

The Makefile automatically routes:
- `make sync sample` → `--stack sample`
- `make sync` → sync all (enhanced with stack kustomizations)
- `REPO=name make sync` → `--repo name` (backward compatible)
- `KUSTOMIZATION=name make sync` → `--kustomization name` (backward compatible)

## Summary

Focus on:
1. **Cross-platform functional parity** (identical user experience)
2. **PowerShell variable expansion gotchas** (most common bug source)
3. **Production code stability** (don't over-optimize working systems)
4. **Explicit error handling** (prevent silent failures)
5. **GitOps sync reliability** (stack-aware sync prevents dependency deadlocks)

When in doubt: preserve complexity that handles real-world scenarios, and always maintain functional parity between .sh and .ps1 implementations.
