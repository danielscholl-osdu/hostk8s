# ADR-002: Make Interface Standardization

## Status
**Accepted** - 2025-07-28

## Context
HostK8s consists of multiple shell scripts for cluster management, each with different calling conventions and environment requirements. Developers needed a consistent, discoverable interface that handles environment setup (KUBECONFIG), validation, and provides standardized commands regardless of the underlying script complexity.

## Decision
Implement a **Make interface as thin orchestration layer** that provides consistent command patterns while delegating complex operations to dedicated, purpose-built bash scripts. Make handles interface concerns (argument parsing, environment setup, dependency chains) while scripts handle operational complexity.

## Rationale
1. **Separation of Concerns**: Make excels at interface/orchestration; bash excels at complex operations
2. **Universal Familiarity**: Standard `make start`, `make test`, `make clean` patterns developers expect
3. **Maintainability**: Complex logic in dedicated scripts is easier to test, debug, and modify
4. **Discoverability**: `make help` provides consistent interface while scripts offer detailed help
5. **Platform Consistency**: Same Make interface across all platforms, regardless of script complexity
6. **Evolution**: Scripts can be enhanced independently without changing user interface

## Architecture Design

### Make Responsibilities (Thin Layer)
- **Command Interface**: Standard `make <command>` patterns
- **Argument Parsing**: Extract and validate arguments using Make's `$(word)` functions
- **Environment Setup**: KUBECONFIG management and variable passing to scripts
- **Dependency Chains**: Ensure prerequisite operations (`up: install`)
- **Script Orchestration**: Route commands to appropriate dedicated scripts

### Script Responsibilities (Complex Operations)
- **Operational Logic**: All complex bash operations, validations, and integrations
- **Error Handling**: Detailed error messages and recovery suggestions
- **Help Systems**: Comprehensive usage documentation with examples
- **Shared Utilities**: Common functions for logging, validation, and kubectl operations
- **Independent Testing**: Each script can be tested and debugged in isolation

### Division of Labor Example
```makefile
# Make handles interface and routing
deploy: ## Deploy application (Usage: make deploy [sample/app1])
	@APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	./infra/scripts/deploy-app.sh "$$APP_NAME"
```

```bash
# Script handles all operational complexity
# - App validation, kubectl operations, error handling, help system
./infra/scripts/deploy-app.sh sample/app2
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

### Argument Handling
```makefile
# Flexible argument support
start: ## Start cluster (Usage: make start [minimal|simple|default])
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "sample" ]; then \
		FLUX_ENABLED=true GITOPS_STAMP="$$ARG" ./infra/scripts/cluster-up.sh; \
	elif [ "$$ARG" = "minimal" ] || [ "$$ARG" = "simple" ]; then \
		KIND_CONFIG="$$ARG" ./infra/scripts/cluster-up.sh; \
	else \
		./infra/scripts/cluster-up.sh; \
	fi
```

## Consequences

**Positive:**
- **Clear Separation**: Make handles interface concerns, scripts handle operational complexity
- **Maintainability**: 68% reduction in Makefile size (424→137 lines) with improved script organization
- **Testability**: Complex operations in dedicated scripts can be tested independently
- **Developer Experience**: Consistent `make` interface with detailed script-level help
- **Evolution**: Scripts can be enhanced without changing user-facing interface
- **Debugging**: Issues isolated to either interface layer (Make) or operational layer (scripts)

**Negative:**
- **Two-Layer System**: Understanding requires familiarity with both Make patterns and script organization
- **Indirection**: Simple operations now route through script calls
- **Dependency**: Requires both Make and bash capabilities across platforms

## Implementation Results

### Script Organization
- `infra/scripts/common.sh` - Shared utilities (logging, validation, kubectl helpers)
- `infra/scripts/install.sh` - Dependency installation and validation
- `infra/scripts/prepare.sh` - Development environment setup
- `infra/scripts/cluster-status.sh` - Comprehensive cluster status reporting
- `infra/scripts/deploy-app.sh` - Application deployment with validation
- `infra/scripts/flux-sync.sh` - Flux reconciliation operations
- `infra/scripts/build.sh` - Docker application build and registry push

### Makefile Simplification
- **Original**: Complex inline bash logic, difficult to maintain and test
- **Optimized**: Thin routing layer, 68% size reduction, consistent patterns
- **Pattern**: `make target` → argument extraction → `./infra/scripts/target.sh args`

## Success Criteria
- All operations accessible via consistent `make <command>` pattern
- Self-documenting help system (`make help`) always current
- Automatic environment management eliminates KUBECONFIG errors
- New developers can discover and use all functions in < 5 minutes
- Scripts can evolve without breaking user interface
- Cross-platform consistency (same commands, same behavior)
