# ADR-002: Make Interface Standardization

## Status
**Accepted** - 2025-07-28

## Context
HostK8s consists of multiple shell scripts for cluster management, each with different calling conventions and environment requirements. Developers needed a consistent, discoverable interface that handles environment setup (KUBECONFIG), validation, and provides standardized commands regardless of the underlying script complexity.

## Decision
Implement a **Make interface as thin orchestration layer** that provides consistent command patterns while delegating complex operations to dedicated, purpose-built platform-native scripts (bash for Unix/Linux/Mac, PowerShell for Windows). Make handles interface concerns (argument parsing, environment setup, dependency chains, cross-platform script selection) while scripts handle operational complexity.

## Rationale
1. **Separation of Concerns**: Make excels at interface/orchestration; platform-native scripts excel at complex operations
2. **Universal Familiarity**: Standard `make start`, `make test`, `make clean` patterns developers expect
3. **Maintainability**: Complex logic in dedicated scripts is easier to test, debug, and modify
4. **Discoverability**: `make help` provides consistent interface while scripts offer detailed help
5. **Platform Consistency**: Same Make interface across all platforms (Unix/Linux/Mac/Windows), with automatic platform detection and script selection
6. **Evolution**: Scripts can be enhanced independently without changing user interface

## Architecture Design

### Make Responsibilities (Thin Layer)
- **Command Interface**: Standard `make <command>` patterns
- **Argument Parsing**: Extract and validate arguments using Make's `$(word)` functions
- **Environment Setup**: KUBECONFIG management and variable passing to scripts
- **Dependency Chains**: Ensure prerequisite operations (`up: install`)
- **Cross-Platform Detection**: Automatic OS detection and script selection (.sh/.ps1)
- **Script Orchestration**: Route commands to appropriate platform-native scripts

### Script Responsibilities (Complex Operations)
- **Operational Logic**: All complex platform-native operations, validations, and integrations
- **Error Handling**: Detailed error messages and recovery suggestions
- **Help Systems**: Comprehensive usage documentation with examples
- **Shared Utilities**: Platform-specific common functions (common.sh/common.ps1) for logging, validation, and kubectl operations
- **Functional Parity**: Identical behavior across platforms despite implementation differences
- **Independent Testing**: Each script can be tested and debugged in isolation

### Division of Labor Example
```makefile
# OS Detection for cross-platform script execution
ifeq ($(OS),Windows_NT)
    SCRIPT_EXT := .ps1
    SCRIPT_RUNNER := pwsh -ExecutionPolicy Bypass -NoProfile -File
else
    SCRIPT_EXT := .sh
    SCRIPT_RUNNER :=
endif

# Make handles interface, OS detection, and routing
deploy: ## Deploy application (Usage: make deploy [sample/app1])
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-app$(SCRIPT_EXT) $(word 2,$(MAKECMDGOALS))
```

```bash
# Unix/Linux/Mac script handles operational complexity
./infra/scripts/deploy-app.sh sample/app2
```

```powershell
# Windows PowerShell script provides identical functionality
./infra/scripts/deploy-app.ps1 sample/app2
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
- **Two-Layer System**: Understanding requires familiarity with both Make patterns and script organization
- **Indirection**: Simple operations now route through script calls
- **Platform Dependencies**: Requires Make plus platform-native scripting (bash on Unix/Linux/Mac, PowerShell 7+ on Windows)
- **Dual Maintenance**: Cross-platform functional parity requires maintaining script pairs

## Implementation Results

### Script Organization
**Cross-Platform Script Pairs (.sh/.ps1):**
- `infra/scripts/common.[sh|ps1]` - Platform-specific utilities (logging, validation, kubectl helpers)
- `infra/scripts/install.[sh|ps1]` - Dependency installation using platform package managers
- `infra/scripts/prepare.[sh|ps1]` - Development environment setup
- `infra/scripts/cluster-status.[sh|ps1]` - Comprehensive cluster status reporting
- `infra/scripts/deploy-app.[sh|ps1]` - Application deployment with validation
- `infra/scripts/flux-sync.[sh|ps1]` - Flux reconciliation operations
- `infra/scripts/build.[sh|ps1]` - Docker application build and registry push
- `infra/scripts/deploy-stack.[sh|ps1]` - Software stack deployment and management
- `infra/scripts/cluster-up.[sh|ps1]` - Advanced cluster creation with fallback configuration
- `infra/scripts/cluster-restart.[sh|ps1]` - Development iteration optimization

**Platform-Specific Implementations:**
- **Unix/Linux/Mac**: Uses brew, apt, native package managers; bash scripting conventions
- **Windows**: Uses winget, chocolatey; PowerShell 7+ scripting conventions
- **Functional Parity**: Identical user experience and outcomes across all platforms

### Makefile Evolution
- **Original**: Complex inline bash logic, difficult to maintain and test
- **Optimized**: Thin routing layer with controlled growth for feature completeness
- **Pattern**: `make target` → argument extraction → `./infra/scripts/target.sh args`
- **Scope Expansion**: Added comprehensive application deployment, source code builds, and extension support
- **Current Size**: 190 lines supporting full platform feature set while maintaining thin layer principle

## Success Criteria
- All operations accessible via consistent `make <command>` pattern
- Self-documenting help system (`make help`) always current
- Automatic environment management eliminates KUBECONFIG errors
- New developers can discover and use all functions in < 5 minutes
- Scripts can evolve without breaking user interface
- Cross-platform consistency (same commands, same behavior across Unix/Linux/Mac/Windows)
