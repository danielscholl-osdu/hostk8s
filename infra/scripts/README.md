# HostK8s Scripts - Python Implementation

Cross-platform Python scripts for HostK8s operations using `uv` for dependency management.

## Architecture

**Core Design**: Single Python implementation per operation, eliminating platform-specific duplication (`.sh`/`.ps1`).

```
infra/scripts/
├── *.py                    # Cross-platform operational scripts (via uv)
├── hostk8s_common.py       # Shared utilities module
├── common.ps1              # Windows Make helper (display only)
└── install.{sh,ps1}        # Platform-specific installers (setup only)
```

**Execution**: All scripts run identically across platforms via `uv run ./infra/scripts/script-name.py`

## Implementation Standards

### 1. Script Template

Every script follows this structure:

```python
#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0.2",      # Standardized versions
#     "rich>=14.1.0",
#     "requests>=2.32.5"
# ]
# ///
"""One-line description."""

# Standard library (alphabetical)
import sys
from pathlib import Path
from typing import Dict, Optional

# Third-party
import yaml
from rich.console import Console

# Local
from hostk8s_common import (
    logger, get_env, run_kubectl,
    HostK8sError, KubectlError
)

def main() -> None:  # Always type-hinted
    """Main entry point."""
    try:
        # Implementation
        pass
    except HostK8sError as e:
        logger.error(str(e))
        sys.exit(1)

if __name__ == '__main__':
    main()
```

### 2. Common Utilities (`hostk8s_common.py`)

| Category | Functions | Purpose |
|----------|-----------|---------|
| **Core** | `run_kubectl()`, `run_flux()`, `detect_kubeconfig()`, `get_env()` | Cross-platform command execution |
| **Validation** | `has_flux()`, `has_flux_cli()`, `validate_kubectl()` | Pre-flight checks |
| **Errors** | `HostK8sError`, `KubectlError` | Structured exception handling |
| **Logging** | `logger.info()`, `logger.warn()`, `logger.error()` | Rich-formatted output |

### 3. Coding Patterns

**Configuration**: Always use `get_env()` for reading, `os.environ` for setting
```python
# Reading
cluster_name = get_env('CLUSTER_NAME', 'hostk8s')

# Setting
os.environ['HELM_HTTP_TIMEOUT'] = '600'
```

**Status Display**: Consistent emoji indicators
```python
print(f"🟢 Service: Ready")           # Running
print(f"🟡 Service: Starting")        # In progress
print(f"⚪ Service: Not installed")   # Not found
print(f"❌ Service: Failed")          # Error
```

**Error Handling**: Structured with proper exit codes
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

## Cross-Platform Design

All scripts are **completely OS-agnostic** - no platform detection or OS-specific behavior.

**✅ DO**
- Use `pathlib.Path` for all file operations
- Use `subprocess.run()` with argument lists (never `shell=True`)
- Rely on cross-platform tools (kubectl, docker, flux)
- Use `get_env()` for configuration

**❌ DON'T**
- No `if platform.system()` conditionals
- No OS-specific executable paths (`kubectl.exe`, `/usr/bin/kubectl`)
- No shell-specific commands (`ps aux | grep`, `Get-Process`)
- No package manager calls (these belong in `install.sh`/`install.ps1`)

### Make Integration

```makefile
# Makefile calls Python scripts uniformly
define SCRIPT_RUNNER_FUNC
uv run ./infra/scripts/$(1).py
endef

# Windows display helpers use common.ps1
ifeq ($(OS),Windows_NT)
	@pwsh -ExecutionPolicy Bypass -File infra/scripts/common.ps1 help
else
	@echo "Help text..."
endif
```

## Script Reference

### Infrastructure
| Script | Purpose | Make Target |
|--------|---------|-------------|
| `cluster-up.py` | Create and configure Kind cluster | `make start` |
| `cluster-down.py` | Stop and cleanup cluster | `make stop` |
| `cluster-status.py` | Comprehensive health check | `make status` |
| `cluster-restart.py` | Quick restart for development | `make restart` |

### GitOps & Applications
| Script | Purpose | Make Target |
|--------|---------|-------------|
| `setup-flux.py` | Install and configure Flux v2 | (called by `cluster-up.py`) |
| `flux-sync.py` | Force reconciliation | `make sync` |
| `flux-suspend.py` | Suspend/resume GitRepository | `make suspend` |
| `deploy-app.py` | Deploy individual app | `make deploy <app>` |
| `deploy-stack.py` | Deploy complete stack | `make up <stack>` |
| `build.py` | Build and push images | `make build src/<app>` |

### Setup & Utilities
| Script | Purpose | Make Target |
|--------|---------|-------------|
| `prepare.py` | Development environment setup | `make prepare` |
| `manage-secrets.py` | Secret management operations | (called by `deploy-stack.py`) |
| `worktree-setup.py` | Git worktree environments | `make worktree` |
| `setup-ingress.py` | Configure NGINX ingress | (called by `cluster-up.py`) |
| `setup-metallb.py` | Configure MetalLB | (called by `cluster-up.py`) |
| `setup-metrics.py` | Configure metrics server | (called by `cluster-up.py`) |
| `setup-registry.py` | Configure local registry | (called by `cluster-up.py`) |
| `setup-vault.py` | Configure Vault + ESO | (called by `cluster-up.py`) |

## Manifest Management

**Principle**: Use static YAML files in `/infra/manifests/` whenever possible.

**Embedded YAML Exceptions** (only for dynamic templating):

| Script | Dynamic Content |
|--------|----------------|
| `setup-flux.py` | Stack path: `./software/stacks/{stack_name}` |
| `deploy-stack.py` | Stack path: `./software/stacks/{stack_name}` |
| `setup-vault.py` | Vault token and namespace URLs |
| `setup-registry.py` | Port configuration: `localhost:{port}` |
| `setup-metallb.py` | IP range from Docker network detection |

## Quick Reference

### Development Workflow
```bash
# Direct execution for testing
uv run ./infra/scripts/cluster-status.py

# Debug mode
DEBUG=true uv run ./infra/scripts/cluster-up.py

# Make integration (preferred)
make status
make up sample
```

### Adding New Scripts
1. Copy template structure from this README
2. Import `hostk8s_common` utilities
3. Add Make target if user-facing
4. Test on Mac, Linux, Windows
5. Document in script reference table

### Quality Checklist
- [ ] Uses `pathlib.Path` for all paths
- [ ] No `shell=True` in subprocess
- [ ] No platform detection
- [ ] Type hints on all functions
- [ ] Proper error handling with exit codes
- [ ] Consistent status emojis
