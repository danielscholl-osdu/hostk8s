# HostK8s - Host-Mode Kubernetes Development Platform
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install start stop up down restart clean status deploy remove sync logs build

# Environment setup
KUBECONFIG_PATH := $(shell pwd)/data/kubeconfig/config
export KUBECONFIG := $(KUBECONFIG_PATH)

# Check if cluster is running
define check_cluster
	@if [ ! -f "$(KUBECONFIG_PATH)" ]; then \
		echo "⚠️  Cluster not found. Run 'make up' first."; \
		exit 1; \
	fi
endef

##@ Setup

help: ## Show this help message
	@echo "HostK8s - Host-Mode Kubernetes Development Platform"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

install: ## Install dependencies and setup environment (Usage: make install [dev])
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "dev" ]; then \
		echo "Setting up development environment..."; \
		./infra/scripts/prepare.sh; \
	else \
		echo "Installing local dependencies..."; \
		QUIET=true ./infra/scripts/install.sh; \
	fi

# Handle dev argument as target to avoid "No rule to make target" errors
dev:
	@:

##@ Infrastructure

start: ## Start cluster (Usage: make start [minimal|simple|default])
	@# Only check dependencies if no cluster config exists (fresh setup)
	@if [ ! -f "$(KUBECONFIG_PATH)" ]; then $(MAKE) install; fi
	@# Start cluster with optional Kind config
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "minimal" ] || [ "$$ARG" = "simple" ] || [ "$$ARG" = "default" ]; then \
		echo "Starting cluster with Kind config: $$ARG"; \
		KIND_CONFIG="$$ARG" ./infra/scripts/cluster-up.sh; \
	elif [ -n "$$ARG" ]; then \
		echo "Unknown Kind config: $$ARG"; \
		echo "Valid options: minimal, simple, default"; \
		exit 1; \
	else \
		KIND_CONFIG=${KIND_CONFIG} ./infra/scripts/cluster-up.sh; \
	fi

stop: ## Stop cluster
	@./infra/scripts/cluster-down.sh

up: ## Deploy software stack (Usage: make up <stack-name>)
	@STACK_NAME="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$STACK_NAME" ]; then \
		echo "Stack name required. Usage: make up <stack-name>"; \
		echo "Available stacks:"; \
		find software/stack -mindepth 1 -maxdepth 1 -type d | sed 's|software/stack/||' || true; \
		exit 1; \
	fi; \
	if [ "$$STACK_NAME" = "sample" ]; then \
		echo "Deploying local software stack: $$STACK_NAME"; \
		if kind get clusters 2>/dev/null | grep -q "^hostk8s$$"; then \
			echo "Cluster exists - deploying software stack to existing cluster..."; \
			SOFTWARE_STACK="$$STACK_NAME" ./infra/scripts/deploy-stack.sh; \
		else \
			echo "Creating new cluster with software stack..."; \
			FLUX_ENABLED=true SOFTWARE_STACK="$$STACK_NAME" ./infra/scripts/cluster-up.sh; \
		fi; \
	elif [[ "$$STACK_NAME" == extension/* ]]; then \
		echo "Deploying extension software stack: $$STACK_NAME"; \
		if kind get clusters 2>/dev/null | grep -q "^hostk8s$$"; then \
			echo "Cluster exists - deploying extension stack to existing cluster..."; \
			SOFTWARE_STACK="$$STACK_NAME" ./infra/scripts/deploy-stack.sh; \
		else \
			echo "Creating new cluster with extension stack..."; \
			FLUX_ENABLED=true SOFTWARE_STACK="$$STACK_NAME" ./infra/scripts/cluster-up.sh; \
		fi; \
	else \
		echo "Unknown stack: $$STACK_NAME"; \
		echo "Available stacks:"; \
		find software/stack -mindepth 1 -maxdepth 1 -type d | sed 's|software/stack/||' || true; \
		exit 1; \
	fi

# Handle arguments as targets to avoid "No rule to make target" errors
minimal simple default sample extension multi-tier %:
	@:

# Handle extension/* patterns
extension/%:
	@:

down: ## Remove software stack (Usage: make down <stack-name>)
	@STACK_NAME="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$STACK_NAME" ]; then \
		echo "Stack name required. Usage: make down <stack-name>"; \
		exit 1; \
	fi; \
	echo "Removing stack: $$STACK_NAME"; \
	./infra/scripts/deploy-stack.sh down "$$STACK_NAME"

restart: ## Quick cluster reset for development iteration (Usage: make restart [stack-name])
	@echo "🔄 Restarting cluster..."
	@# Determine if argument is a software stack
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ -n "$$ARG" ]; then \
		echo "🎯 Restarting with software stack: $$ARG"; \
		FLUX_ENABLED=true SOFTWARE_STACK="$$ARG" ./infra/scripts/cluster-restart.sh; \
	else \
		./infra/scripts/cluster-restart.sh; \
	fi

clean: ## Complete cleanup (destroy cluster and data)
	@./infra/scripts/cluster-down.sh 2>/dev/null || true
	@kind delete cluster --name hostk8s 2>/dev/null || true
	@rm -rf data/ 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true

status: ## Show cluster health and running services
	@./infra/scripts/cluster-status.sh

sync: ## Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])
	@if [ -n "$(REPO)" ]; then \
		./infra/scripts/flux-sync.sh --repo "$(REPO)"; \
	elif [ -n "$(KUSTOMIZATION)" ]; then \
		./infra/scripts/flux-sync.sh --kustomization "$(KUSTOMIZATION)"; \
	else \
		./infra/scripts/flux-sync.sh; \
	fi

##@ Applications

deploy: ## Deploy application (Usage: make deploy <app-name>)
	@APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$APP_NAME" ]; then \
		echo "Application name required. Usage: make deploy <app-name>"; \
		echo "Available applications:"; \
		find software/apps -mindepth 1 -maxdepth 1 -type d | sed 's|software/apps/||' || true; \
		exit 1; \
	fi; \
	./infra/scripts/deploy-app.sh "$$APP_NAME"

remove: ## Remove application (Usage: make remove <app-name>)
	@APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	if [ -z "$$APP_NAME" ]; then \
		echo "Application name required. Usage: make remove <app-name>"; \
		exit 1; \
	fi; \
	./infra/scripts/deploy-app.sh remove "$$APP_NAME"

# Handle app arguments as targets to avoid "No rule to make target" errors
extension/sample registry-demo:
	@:

# Handle src/* arguments as targets to avoid "No rule to make target" errors
src/%:
	@:

##@ Development Tools

logs: ## View recent cluster events and logs
	$(call check_cluster)
	@./infra/scripts/utils.sh logs $(filter-out logs,$(MAKECMDGOALS))

build: ## Build and push application from src/ (Usage: make build src/APP_NAME)
	@APP_PATH="$(word 2,$(MAKECMDGOALS))"; \
	./infra/scripts/build.sh "$$APP_PATH"

	@if [ -f "$(KUBECONFIG_PATH)" ]; then \
		echo "✅ Kubeconfig found: $(KUBECONFIG_PATH)"; \
		echo "🔗 MCP configuration: .mcp.json"; \
	else \
		echo "❌ Cluster not running. Run 'make up' to start cluster."; \
	fi
