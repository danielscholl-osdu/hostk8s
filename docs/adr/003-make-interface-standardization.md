# ADR-003: Make Interface Standardization

## Status
**Accepted** - 2025-01-15

## Context
HostK8s consists of multiple shell scripts for cluster management, each with different calling conventions and environment requirements. Developers needed a consistent, discoverable interface that handles environment setup (KUBECONFIG), validation, and provides standardized commands regardless of the underlying script complexity.

## Decision
Implement a **standardized Make interface** that wraps all operational scripts with consistent conventions, automatic environment management, and universal command patterns.

## Rationale
1. **Universal Familiarity**: Make is available on all development platforms (Mac, Linux, Windows)
2. **Standard Conventions**: `make up`, `make test`, `make clean` patterns developers expect
3. **Environment Management**: Automatic KUBECONFIG handling eliminates common errors
4. **Discoverability**: `make help` provides self-documenting interface
5. **Validation**: Built-in dependency and state checking before operations
6. **Consistency**: Same command syntax regardless of underlying script complexity

## Interface Design

### Standard Command Patterns
```bash
make help      # Self-documenting help system
make up        # Start/create resources
make down      # Stop resources (preserve data)
make restart   # Quick reset for development
make clean     # Complete cleanup
make test      # Validation and testing
make status    # Health and status information
make deploy    # Application deployment
make logs      # Debug information
```

### Automatic Environment Management
```makefile
# Automatic KUBECONFIG management
KUBECONFIG_PATH := $(shell pwd)/data/kubeconfig/config
export KUBECONFIG := $(KUBECONFIG_PATH)

# Pre-flight checks
define check_cluster
	@if [ ! -f "$(KUBECONFIG_PATH)" ]; then \
		echo "⚠️  Cluster not found. Run 'make up' first."; \
		exit 1; \
	fi
endef
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
up: ## Start cluster (Usage: make up [minimal|simple|default|sample])
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
- **Developer Experience**: Consistent, discoverable commands across all operations
- **Error Prevention**: Automatic environment validation prevents common mistakes
- **Onboarding**: New developers immediately understand available operations
- **Documentation**: Self-documenting help system stays current with implementation
- **Platform Consistency**: Same commands work identically across Mac, Linux, Windows
- **Script Evolution**: Underlying scripts can change without affecting user interface

**Negative:**
- **Abstraction Layer**: Adds indirection between user and actual implementation
- **Make Dependency**: Requires Make (though universally available)
- **Argument Limitations**: Make's argument handling is less flexible than dedicated CLI
- **Debugging Complexity**: Errors may require understanding both Make and script layers

## Design Patterns

### Dependency Chain Management
```makefile
up: install          # Automatically ensures dependencies
deploy: up           # Ensures cluster exists before deployment  
test: deploy         # Ensures application deployed before testing
```

### Error Handling
```makefile
clean: ## Complete cleanup
	@./infra/scripts/cluster-down.sh 2>/dev/null || true
	@kind delete cluster --name osdu-ci 2>/dev/null || true
	@rm -rf data/kubeconfig/ 2>/dev/null || true
	@echo "✅ Cleanup complete"
```

### Parallel Operations
```makefile
# Multiple operations in parallel where safe
status:
	@export KUBECONFIG="$(KUBECONFIG_PATH)"; \
	kubectl get nodes & \
	kubectl get pods -A & \
	wait
```

## Success Criteria
- ✅ All operations accessible via consistent `make <command>` pattern
- ✅ Self-documenting help system (`make help`) always current
- ✅ Automatic environment management eliminates KUBECONFIG errors
- ✅ New developers can discover and use all functions in < 5 minutes
- ✅ Scripts can evolve without breaking user interface
- ✅ Cross-platform consistency (same commands, same behavior)