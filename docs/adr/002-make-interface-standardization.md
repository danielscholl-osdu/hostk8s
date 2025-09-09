# ADR-002: Make Interface Standardization

## Status
**Accepted** - 2025-07-28

## Context
HostK8s consists of multiple Python scripts for cluster management, each with different calling conventions and environment requirements. Developers needed a consistent, discoverable interface that handles environment setup (KUBECONFIG), validation, and provides standardized commands regardless of the underlying script complexity.

## Decision
Implement a **Make interface as thin orchestration layer** that provides consistent command patterns while delegating complex operations to dedicated, cross-platform Python scripts. Make handles interface concerns (argument parsing, environment setup, dependency chains) while Python scripts provide unified operational logic across all platforms via `uv` execution.

## Rationale
1. **Separation of Concerns**: Make excels at interface/orchestration; Python scripts excel at cross-platform operations
2. **Universal Familiarity**: Standard `make start`, `make test`, `make clean` patterns developers expect
3. **Maintainability**: Complex logic in dedicated Python scripts is easier to test, debug, and modify
4. **Discoverability**: `make help` provides consistent interface while scripts offer detailed help
5. **Platform Consistency**: Same Make interface across all platforms with unified Python execution via `uv`
6. **Evolution**: Scripts can be enhanced independently without changing user interface

## Architecture Design

### Make Responsibilities (Thin Layer)
- **Command Interface**: Standard `make <command>` patterns
- **Argument Parsing**: Extract and validate arguments using Make's `$(word)` functions
- **Environment Setup**: KUBECONFIG management and variable passing to scripts
- **Dependency Chains**: Ensure prerequisite operations (`up: install`)
- **Script Orchestration**: Route commands to Python scripts via `uv run`

### Python Script Responsibilities (Cross-Platform Operations)
- **Operational Logic**: All complex operations, validations, and integrations
- **Error Handling**: Structured exceptions with detailed error messages and recovery suggestions
- **Help Systems**: Comprehensive argparse-based help with examples
- **Shared Utilities**: Cross-platform common module (`hostk8s_common.py`) for logging, validation, and kubectl operations
- **Self-Contained Dependencies**: PEP 723 headers define script-specific requirements
- **Independent Testing**: Each script can be tested and debugged in isolation across all platforms

### Division of Labor Example
```makefile
# Unified Python script execution via uv
define SCRIPT_RUNNER_FUNC
uv run ./infra/scripts/$(1).py
endef

# Make handles interface and routing to Python scripts
deploy: ## Deploy application (Usage: make deploy [sample/app1])
	@$(call SCRIPT_RUNNER_FUNC,deploy-app) $(word 2,$(MAKECMDGOALS))
```

```python
# Cross-platform Python script handles operational complexity
#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "pyyaml>=6.0",
#     "rich>=13.0.0"
# ]
# ///

# Unified implementation works across all platforms
from hostk8s_common import logger, run_kubectl
# ... implementation
```

## Alternatives Considered

### 1. Direct Script Execution
- **Pros**: No abstraction layer, direct control
- **Cons**: Inconsistent interfaces, manual environment management, poor discoverability
- **Decision**: Rejected due to developer experience issues

### 2. Custom CLI Tool
- **Pros**: Rich functionality, custom help system, advanced features
- **Cons**: Additional dependency, platform compilation, maintenance overhead
- **Decision**: Rejected due to simplicity preference

### 3. Task/Taskfile
- **Pros**: Modern task runner, rich features, YAML configuration
- **Cons**: Additional dependency, less universal than Make
- **Decision**: Rejected due to additional dependency

### 4. Shell Functions/Aliases
- **Pros**: No additional tools, shell-native
- **Cons**: Shell-specific, poor discoverability, no dependency management
- **Decision**: Rejected due to portability concerns

### 5. npm/yarn Scripts
- **Pros**: Rich ecosystem, familiar to web developers
- **Cons**: Requires Node.js, not universal for infrastructure projects
- **Decision**: Rejected due to dependency requirements

## Implementation Benefits

### Self-Documenting Interface
```bash
$ make help
HostK8s - Host-Mode Kubernetes Development Platform

Usage: make <target>

Setup:
  help           Show this help message
  install        Install required dependencies (kind, kubectl, helm, flux)
  prepare        Setup development environment (pre-commit, yamllint, hooks)

Cluster Operations:
  up             Start cluster with dependencies check
  down           Stop the Kind cluster (preserves data)
  restart        Quick cluster reset for development iteration
  clean          Complete cleanup (destroy cluster and data)
  status         Show cluster health and running services
```

### Environment Safety
```makefile
# Prevents operations on wrong cluster
up: install
	@echo "🚀 Starting cluster..."
	@./infra/scripts/cluster-up.sh
	@echo "💡 export KUBECONFIG=$(pwd)/data/kubeconfig/config"
	@kubectl get nodes

deploy:
	$(call check_cluster)  # Validates cluster exists before deployment
	@echo "📦 Deploying application..."
```

### Advanced Argument Handling
```makefile
# Comprehensive argument support for applications
deploy: ## Deploy application (Usage: make deploy [app-name] [namespace])
	@APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	POSITIONAL_NS="$(word 3,$(MAKECMDGOALS))"; \
	TARGET_NAMESPACE="$${POSITIONAL_NS:-$${NAMESPACE:-default}}"; \
	if [ -z "$$APP_NAME" ]; then \
		APP_NAME="simple"; \
		echo "No app specified, using default: $$APP_NAME"; \
	fi; \
	./infra/scripts/deploy-app.sh "$$APP_NAME" "$$TARGET_NAMESPACE"

# Source code builds with path validation
build: ## Build and push application from src/
	@APP_PATH="$(word 2,$(MAKECMDGOALS))"; \
	./infra/scripts/build.sh "$$APP_PATH"

# Extension stack deployment with template processing
up: ## Deploy software stack with extension support
	@STACK_NAME="$(word 2,$(MAKECMDGOALS))"; \
	if [[ "$$STACK_NAME" == extension/* ]]; then \
		echo "Deploying extension software stack: $$STACK_NAME"; \
		./infra/scripts/deploy-stack.sh "$$STACK_NAME"; \
	fi
```

## Consequences

**Positive:**
- **Clear Separation**: Make handles interface concerns, scripts handle operational complexity
- **Maintainability**: Structured growth from 137→190 lines supporting expanded feature set
- **Testability**: Complex operations in dedicated scripts can be tested independently
- **Developer Experience**: Consistent `make` interface with detailed script-level help
- **Evolution**: Scripts can be enhanced without changing user-facing interface
- **Debugging**: Issues isolated to either interface layer (Make) or operational layer (scripts)
- **Feature Coverage**: Comprehensive support for applications, source builds, and extensions

**Negative:**
- **Two-Layer System**: Understanding requires familiarity with both Make patterns and Python script organization
- **Indirection**: Simple operations now route through script calls
- **Platform Dependencies**: Requires Make, Python 3.8+, and `uv` tool

## Implementation Results

### Script Organization
**Cross-Platform Python Scripts:**
- `infra/scripts/hostk8s_common.py` - Shared utilities (logging, validation, kubectl helpers)
- `infra/scripts/install.[sh|ps1]` - Platform-specific dependency installation (only remaining shell scripts)
- `infra/scripts/prepare.py` - Development environment setup
- `infra/scripts/cluster-status.py` - Comprehensive cluster status reporting
- `infra/scripts/deploy-app.py` - Application deployment with validation
- `infra/scripts/flux-sync.py` - Flux reconciliation operations
- `infra/scripts/build.py` - Docker application build and registry push
- `infra/scripts/deploy-stack.py` - Software stack deployment and management
- `infra/scripts/cluster-up.py` - Advanced cluster creation with fallback configuration
- `infra/scripts/cluster-restart.py` - Development iteration optimization
- `infra/scripts/setup-*.py` - Infrastructure component setup scripts
- `infra/scripts/worktree-setup.py` - Git worktree development environments

**Implementation Features:**
- **Cross-Platform**: Single Python implementation works across all platforms via `uv`
- **Self-Contained**: PEP 723 headers define script-specific dependencies
- **Rich Output**: Enhanced terminal experience with colors, emojis, and progress indicators
- **Structured Error Handling**: Python exceptions provide detailed error information

### Makefile Evolution
- **Original**: Complex inline bash logic, difficult to maintain and test
- **Optimized**: Thin routing layer with controlled growth for feature completeness
- **Pattern**: `make target` → argument extraction → `uv run ./infra/scripts/target.py args`
- **Scope Expansion**: Added comprehensive application deployment, source code builds, and extension support
- **Current Size**: ~172 lines supporting full platform feature set while maintaining thin layer principle
- **Simplified**: Eliminated OS detection complexity - unified Python execution via `uv`

## Success Criteria
- All operations accessible via consistent `make <command>` pattern
- Self-documenting help system (`make help`) always current
- Automatic environment management eliminates KUBECONFIG errors
- New developers can discover and use all functions in < 5 minutes
- Python scripts can evolve without breaking user interface
- Cross-platform consistency via unified Python execution (same commands, same behavior across all platforms)
- Single script implementation eliminates dual maintenance burden
