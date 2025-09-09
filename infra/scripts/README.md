# HostK8s Scripts - Python Implementation Guidelines

Modern Python-based scripts for HostK8s cross-platform operations using `uv` for dependency management and execution.

## Architecture Overview

All HostK8s scripts are now **Python-based** with cross-platform execution via `uv run`:
- **Single Implementation**: One Python script per operation (eliminates `.sh`/`.ps1` duplication)
- **Universal Execution**: `uv run ./infra/scripts/script-name.py` works on all platforms
- **Rich Terminal Output**: Enhanced CLI experience with colors, emojis, and progress indicators
- **Integrated Dependencies**: Each script defines its own requirements via PEP 723

## Core Principles

1. **Cross-Platform by Design**: Python provides native cross-platform execution
2. **Reliability First**: Comprehensive error handling and graceful failures
3. **Rich User Experience**: Clear status indicators and helpful error messages
4. **Self-Contained**: Each script manages its own dependencies via `uv`

## Script Structure

### Required Script Header (PEP 723)
```python
#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0",
#     "rich>=13.0.0",
#     "requests>=2.28.0"
# ]
# ///

"""
Script Description

Detailed explanation of what this script does.
"""

import sys
from pathlib import Path

# Import common utilities
from hostk8s_common import (
    logger, HostK8sError, KubectlError,
    run_kubectl, detect_kubeconfig, get_env
)
```

### Common Utilities (`hostk8s_common.py`)

The shared module provides:

**Core Functions:**
- `run_kubectl()` - Execute kubectl with error handling
- `run_flux()` - Execute flux CLI commands
- `detect_kubeconfig()` - Find and validate kubeconfig
- `get_env()` - Environment variable handling with defaults

**Validation Functions:**
- `has_flux()` - Check if Flux is installed
- `has_flux_cli()` - Check if Flux CLI is available
- `validate_kubectl()` - Ensure kubectl is functional

**Error Classes:**
- `HostK8sError` - Base exception for HostK8s operations
- `KubectlError` - kubectl command failures

**Logging:**
- Rich-formatted logging with colors and emojis
- Consistent log levels: `logger.info()`, `logger.warn()`, `logger.error()`

## Best Practices

### Error Handling
```python
try:
    result = run_kubectl(['get', 'pods'], check=False)
    if result.returncode != 0:
        logger.error("Failed to get pods")
        sys.exit(1)
except (KubectlError, HostK8sError) as e:
    logger.error(f"Operation failed: {e}")
    sys.exit(1)
```

### Environment Detection
```python
# Use helper functions from hostk8s_common
kubeconfig = detect_kubeconfig()
flux_enabled = get_env('FLUX_ENABLED', 'false') == 'true'

# Cross-platform paths
data_dir = Path.cwd() / 'data'
kubeconfig_path = data_dir / 'kubeconfig' / 'config'
```

### Rich Output Formatting
```python
from rich.console import Console

console = Console()

# Colored output
console.print(f"✅ Status: [green]Ready[/green]")
console.print(f"🔄 Processing: [yellow]In Progress[/yellow]")
console.print(f"❌ Error: [red]Failed[/red]")

# Links and highlighting
console.print(f"Access: [cyan]http://localhost:8080[/cyan]")
```

### Status Checking Pattern
```python
def _check_service(self):
    """Check service status with consistent formatting."""
    try:
        result = run_kubectl(['get', 'deployment', 'service-name',
                            '-n', 'namespace', '--no-headers'], check=False)

        if result.returncode == 0 and result.stdout:
            # Parse and display status
            parts = result.stdout.strip().split()
            ready = parts[1]  # e.g., "1/1"

            if ready == "1/1":
                print(f"🟢 Service: Ready")
                print(f"   Status: Available and healthy")
            else:
                print(f"🟡 Service: Starting ({ready} ready)")
        else:
            print(f"⚪ Service: Not installed")
    except Exception as e:
        logger.debug(f"Error checking service: {e}")
```

## Code Standardization Patterns

### Dependency Management
All scripts use consistent PEP 723 headers with standardized library versions:

```python
#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0.2",
#     "rich>=14.1.0",
#     "requests>=2.32.5"
# ]
# ///
```

**Key Points:**
- **uv execution**: All scripts use `uv run` for isolated execution
- **Library versions**: Standardized across all scripts for consistency
- **Dependency ordering**: Always `pyyaml`, `rich`, `requests` for consistency

### Import Organization
Imports follow PEP 8 guidelines with consistent ordering:

```python
# Standard library imports (alphabetical)
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Third-party imports (separated with blank line)
import yaml
from rich.console import Console

# Local imports (separated with blank line)
from hostk8s_common import (
    logger, get_env, run_kubectl
)
```

**Pattern:**
1. Standard library imports (alphabetical)
2. Third-party library imports
3. Local application imports

### Configuration Management
Use the `get_env()` utility for all configuration reading:

```python
# ✅ Preferred: Standardized pattern with defaults
cluster_name = get_env('CLUSTER_NAME', 'hostk8s')
vault_enabled = get_env('VAULT_ENABLED', 'false').strip().lower() == 'true'

# ❌ Avoid: Direct os.environ access for configuration
cluster_name = os.environ.get('CLUSTER_NAME', 'hostk8s')  # Inconsistent
```

**Exception:** Setting environment variables uses `os.environ` directly:
```python
# ✅ OK: Setting environment variables
os.environ['HELM_HTTP_TIMEOUT'] = '600'
os.environ['PATH'] = f"{local_bin_str}:{current_path}"
```

### Type Hints
All functions include proper type annotations:

```python
# Main functions
def main() -> None:
    """Main entry point."""
    pass

# Build functions that return exit codes
def main() -> int:
    """Main entry point."""
    return 0

# Methods with parameters
def check_service(self, name: str, namespace: str = "default") -> bool:
    """Check if service is running."""
    return True

# Complex return types
def get_cluster_info(self) -> Dict[str, Any]:
    """Get cluster information."""
    return {"status": "ready"}
```

**Guidelines:**
- All `main()` functions have return type hints (`-> None` or `-> int`)
- Method parameters include type hints where helpful
- Complex return types use proper typing imports
- `__init__` methods don't need return type (implicit `-> None`)

## Script Categories

### Infrastructure Scripts
- `cluster-up.py` - Create and configure Kind cluster
- `cluster-down.py` - Stop and cleanup cluster
- `cluster-status.py` - Comprehensive cluster health check
- `cluster-restart.py` - Quick restart for development

### GitOps Scripts
- `setup-flux.py` - Install and configure Flux v2
- `flux-sync.py` - Force reconciliation with stack-aware sync
- `flux-suspend.py` - Suspend/resume GitRepository sources

### Application Scripts
- `deploy-app.py` - Deploy individual applications
- `deploy-stack.py` - Deploy complete GitOps stacks
- `build.py` - Build and push container images

### Setup Scripts
- `prepare.py` - Development environment setup
- `manage-secrets.py` - Secret management operations

### Utility Scripts
- `worktree-setup.py` - Git worktree development environments

## Environment Integration

### Make Interface
All scripts are called via Makefile using the `SCRIPT_RUNNER_FUNC`:
```makefile
define SCRIPT_RUNNER_FUNC
uv run ./infra/scripts/$(1).py
endef
```

### Example Usage
```bash
make status           # uv run ./infra/scripts/cluster-status.py
make up sample        # uv run ./infra/scripts/deploy-stack.py sample
make sync --stack api # uv run ./infra/scripts/flux-sync.py --stack api
```

## Debugging and Development

### Direct Execution
```bash
# Run scripts directly for testing
uv run ./infra/scripts/cluster-status.py
uv run ./infra/scripts/deploy-app.py simple default

# Debug mode (set in hostk8s_common.py)
DEBUG=true uv run ./infra/scripts/cluster-up.py
```

### Adding New Scripts

1. **Create script with PEP 723 header**
2. **Import from hostk8s_common** for consistency
3. **Add to Makefile** if needed
4. **Test cross-platform** on Mac, Linux, Windows
5. **Document usage** in this README

### Testing Pattern
```python
def main():
    """Main entry point with error handling."""
    try:
        # Main logic here
        perform_operation()
    except HostK8sError as e:
        logger.error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        logger.warn("Operation cancelled by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

## Cross-Platform Design Principles

### OS Agnosticism Goals
All HostK8s Python scripts are designed to be **completely OS-agnostic**, running identically on Windows, Mac, and Linux without platform-specific behavior.

### ✅ Preferred Cross-Platform Patterns
- **Path Handling**: Always use `pathlib.Path` for file system operations
- **Command Execution**: Use `subprocess.run()` with argument lists (never `shell=True`)
- **File Operations**: Standard Python file I/O works identically across platforms
- **Environment Variables**: Use `os.environ` and `get_env()` utility for consistent behavior
- **External Commands**: Rely on cross-platform tools (kubectl, docker, flux) that handle OS differences internally

### ✅ Acceptable OS-Awareness Patterns

**1. Library Optimizations (Handled Internally)**
```python
# Rich console optimization - library handles OS differences
Console(legacy_windows=False)  # ✅ OK: Rich handles this internally
```

**2. Informational Help Messages (Non-Functional)**
```python
# Help suggestions that don't execute platform-specific code
logger.info('For bash: echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.bashrc')
logger.info('For zsh: echo \'export PATH="$HOME/.local/bin:$PATH"\' >> ~/.zshrc')
```

**3. Documentation Comments (Explanatory)**
```python
# Comments explaining cross-platform design decisions
# ✅ OK: Pure documentation, no executable code
```

### ❌ Patterns to Avoid

**Platform Detection Logic**
```python
# ❌ AVOID: Never use OS detection conditionals
if platform.system() == "Windows":
    do_windows_thing()
elif platform.system() == "Darwin":
    do_mac_thing()
```

**Platform-Specific Executables**
```python
# ❌ AVOID: OS-specific executable paths
if os.name == 'nt':
    cmd = ['kubectl.exe']
else:
    cmd = ['/usr/bin/kubectl']
```

**Shell-Specific Commands**
```python
# ❌ AVOID: Shell=True usage breaks cross-platform compatibility
subprocess.run("powershell -Command 'Get-Process'", shell=True)  # Windows-only
subprocess.run("ps aux | grep kubectl", shell=True)  # Unix-only
```

**Package Manager Detection**
```python
# ❌ AVOID: OS-specific package managers in operational scripts
# These belong only in install.sh/install.ps1
if platform.system() == "Windows":
    subprocess.run(["winget", "install", "package"])
elif platform.system() == "Darwin":
    subprocess.run(["brew", "install", "package"])
```

### Implementation Guidelines

**For New Scripts:**
1. **Test Cross-Platform**: Verify script works identically on Windows, Mac, Linux
2. **Use Python Standard Library**: Prefer built-in cross-platform modules
3. **Leverage Common Utilities**: Use `hostk8s_common.py` functions for consistent behavior
4. **Path Handling**: Always use `pathlib.Path` instead of string concatenation
5. **External Commands**: Ensure all external tools (kubectl, docker, etc.) are cross-platform

**For External Dependencies:**
- Only accept external tools that work identically across platforms
- Document any platform-specific installation requirements in install scripts
- Never make operational scripts dependent on OS-specific tools

### Quality Assurance Checklist

**Before Script Completion:**
- [ ] Script uses `pathlib.Path` for all file operations
- [ ] No `shell=True` usage in subprocess calls
- [ ] No platform detection conditionals (`if platform.system()`)
- [ ] No OS-specific executable names or paths
- [ ] All external commands work on Windows, Mac, and Linux
- [ ] Help text doesn't assume specific platform capabilities

This design philosophy ensures that HostK8s remains truly portable and provides a consistent experience regardless of the developer's operating system.

## Kubernetes Manifest Management

### Preferred Pattern: External Manifests
Most scripts use static YAML files from `infra/manifests/`:
- `setup-ingress.py` → `nginx-ingress.yaml`
- `setup-metallb.py` → `metallb.yaml`
- `setup-metrics.py` → `metrics-server.yaml`
- `setup-registry.py` → `registry-ui.yaml`
- `setup-vault.py` → `vault-ingress.yaml`

### Embedded YAML (Dynamic Content Only)
Some scripts contain embedded YAML for dynamic templating that cannot be achieved with static files:

| Script | Resource | Justification |
|--------|----------|---------------|
| `setup-flux.py` | Bootstrap Kustomization | Dynamic stack path: `./software/stacks/{stack_name}` |
| `deploy-stack.py` | Bootstrap Kustomization | Dynamic stack path: `./software/stacks/{stack_name}` |
| `setup-vault.py` | ClusterSecretStore + Token Secret | Dynamic vault token and namespace-specific URLs |
| `setup-registry.py` | Local Registry ConfigMap | Dynamic port configuration: `localhost:{port}` |
| `setup-metallb.py` | IPAddressPool + L2Advertisement | Dynamic IP range from Docker network detection |

### Guidelines
- **Use `infra/manifests/`** for static Kubernetes resources
- **Embed YAML only when** runtime templating/configuration is required
- **Document justification** for any new embedded YAML in this table

## Summary

Focus on:
1. **Python Implementation** - Single codebase for all platforms
2. **Rich User Experience** - Clear status, colors, helpful messages
3. **Robust Error Handling** - Structured exceptions and graceful failures
4. **Cross-Platform Native** - Python provides natural cross-platform support
5. **Modern Development** - Type hints, proper logging, dependency management

The Python architecture provides excellent development experience with reliable cross-platform operations.
