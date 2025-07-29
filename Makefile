# HostK8s - Host-Mode Kubernetes Development Platform
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install clean up down restart prepare test status deploy logs port-forward build

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

install: ## Install required dependencies (kind, kubectl, helm, flux)
	@./infra/scripts/install.sh

prepare: ## Setup development environment (pre-commit, yamllint, hooks)
	@./infra/scripts/prepare.sh

##@ Cluster Operations

up: install ## Start cluster with dependencies check (Usage: make up [minimal|simple|default|sample])
	@echo "🚀 Starting cluster..."
	@# Determine if argument is a Kind config or GitOps stamp
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "sample" ]; then \
		echo "🎯 Detected GitOps stamp: $$ARG"; \
		FLUX_ENABLED=true GITOPS_STAMP="$$ARG" ./infra/scripts/cluster-up.sh; \
	elif [ "$$ARG" = "minimal" ] || [ "$$ARG" = "simple" ] || [ "$$ARG" = "default" ]; then \
		echo "🎯 Detected Kind config: $$ARG"; \
		KIND_CONFIG="$$ARG" ./infra/scripts/cluster-up.sh; \
	elif [ -n "$$ARG" ]; then \
		echo "❌ Unknown argument: $$ARG"; \
		echo "Valid options: minimal, simple, default (Kind configs) | sample (GitOps stamp)"; \
		exit 1; \
	else \
		KIND_CONFIG=${KIND_CONFIG} ./infra/scripts/cluster-up.sh; \
	fi
	@echo ""
	@echo "💡 export KUBECONFIG=\$$(pwd)/data/kubeconfig/config"
	@echo ""
	@kubectl get nodes

# Handle arguments as targets to avoid "No rule to make target" errors
minimal simple default sample:
	@:

down: ## Stop the Kind cluster (preserves data)
	@echo "🛑 Stopping cluster..."
	@./infra/scripts/cluster-down.sh

restart: ## Quick cluster reset for development iteration (Usage: make restart [sample])
	@echo "🔄 Restarting cluster..."
	@# Determine if argument is a GitOps stamp
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "sample" ]; then \
		echo "🎯 Restarting with GitOps stamp: $$ARG"; \
		FLUX_ENABLED=true GITOPS_STAMP="$$ARG" ./infra/scripts/cluster-restart.sh; \
	elif [ -n "$$ARG" ]; then \
		echo "❌ Unknown stamp: $$ARG"; \
		echo "Valid stamps: sample"; \
		exit 1; \
	else \
		./infra/scripts/cluster-restart.sh; \
	fi

clean: ## Complete cleanup (destroy cluster and data)
	@echo "🧹 Cleaning up everything..."
	@./infra/scripts/cluster-down.sh 2>/dev/null || true
	@kind delete cluster --name osdu-ci 2>/dev/null || true
	@rm -rf data/kubeconfig/ 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "✅ Cleanup complete"

status: ## Show cluster health and running services
	@./infra/scripts/status.sh

sync: ## Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])
	@if [ -n "$(REPO)" ]; then \
		./infra/scripts/sync.sh --repo "$(REPO)"; \
	elif [ -n "$(KUSTOMIZATION)" ]; then \
		./infra/scripts/sync.sh --kustomization "$(KUSTOMIZATION)"; \
	else \
		./infra/scripts/sync.sh; \
	fi

##@ Tools

deploy: ## Deploy application (Usage: make deploy [sample/app1])
	@APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	./infra/scripts/deploy.sh "$$APP_NAME"

# Handle app arguments as targets to avoid "No rule to make target" errors
app1 app2 app3 sample/app1 sample/app2 sample/app3 sample/registry-demo:
	@:

# Handle src/* arguments as targets to avoid "No rule to make target" errors
src/%:
	@:

test: ## Run comprehensive cluster validation tests
	$(call check_cluster)
	@echo "🧪 Running comprehensive validation tests..."
	@./infra/scripts/validate-cluster.sh

logs: ## View recent cluster events and logs
	$(call check_cluster)
	@./infra/scripts/utils.sh logs

port-forward: ## Port forward a service (make port-forward SVC=myservice PORT=8080)
	$(call check_cluster)
	@SVC=${SVC}; PORT=${PORT:-8080}; \
	if [ -z "$$SVC" ]; then \
		echo "Usage: make port-forward SVC=myservice [PORT=8080]"; \
		echo "Available services:"; \
		kubectl get svc; \
	else \
		./infra/scripts/utils.sh forward "$$SVC" "$$PORT"; \
	fi

##@ Source Code Operations

build: ## Build and push application from src/ (Usage: make build src/APP_NAME)
	@APP_PATH="$(word 2,$(MAKECMDGOALS))"; \
	./infra/scripts/build.sh "$$APP_PATH"
