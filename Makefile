# OSDU-CI Host-Mode Kubernetes Development Environment
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install clean up down restart prepare test status deploy logs port-forward

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

##@ Standard Targets

help: ## Show this help message
	@echo "OSDU-CI Development Environment"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

install: ## Install required dependencies (kind, kubectl, helm, flux)
	@echo "🔧 Checking dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		echo "Using Homebrew (macOS)..."; \
		command -v kind >/dev/null 2>&1 || (echo "Installing kind..." && brew install kind); \
		command -v kubectl >/dev/null 2>&1 || (echo "Installing kubectl..." && brew install kubectl); \
		command -v helm >/dev/null 2>&1 || (echo "Installing helm..." && brew install helm); \
		command -v flux >/dev/null 2>&1 || (echo "Installing flux..." && brew install fluxcd/tap/flux); \
	elif command -v apk >/dev/null 2>&1; then \
		echo "CI environment detected - dependencies should be pre-installed"; \
		command -v kind >/dev/null 2>&1 || (echo "❌ kind not found" && exit 1); \
		command -v kubectl >/dev/null 2>&1 || (echo "❌ kubectl not found" && exit 1); \
		command -v helm >/dev/null 2>&1 || (echo "❌ helm not found" && exit 1); \
		command -v flux >/dev/null 2>&1 || (echo "❌ flux not found" && exit 1); \
	elif command -v apt >/dev/null 2>&1; then \
		echo "Ubuntu/Debian environment detected - dependencies should be pre-installed"; \
		command -v kind >/dev/null 2>&1 || (echo "❌ kind not found" && exit 1); \
		command -v kubectl >/dev/null 2>&1 || (echo "❌ kubectl not found" && exit 1); \
		command -v helm >/dev/null 2>&1 || (echo "❌ helm not found" && exit 1); \
		command -v flux >/dev/null 2>&1 || (echo "❌ flux not found" && exit 1); \
	else \
		echo "❌ Unsupported environment. Please install tools manually or use macOS with Homebrew."; \
		exit 1; \
	fi
	@command -v docker >/dev/null 2>&1 || (echo "❌ Docker not available" && exit 1)
	@echo "✅ All dependencies verified"

clean: ## Complete cleanup (destroy cluster and data)
	@echo "🧹 Cleaning up everything..."
	@./infra/scripts/cluster-down.sh 2>/dev/null || true
	@kind delete cluster --name osdu-ci 2>/dev/null || true
	@rm -rf data/kubeconfig/ 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "✅ Cleanup complete"

##@ Cluster Operations

up: install ## Start cluster with dependencies check (Usage: make up [minimal|simple|default])
	@echo "🚀 Starting cluster..."
	@if [ "$(filter-out up,$@)" ]; then \
		KIND_CONFIG="$(filter-out up,$@)" ./infra/scripts/cluster-up.sh; \
	elif [ -n "$(word 2,$(MAKECMDGOALS))" ]; then \
		KIND_CONFIG="$(word 2,$(MAKECMDGOALS))" ./infra/scripts/cluster-up.sh; \
	else \
		KIND_CONFIG=${KIND_CONFIG} ./infra/scripts/cluster-up.sh; \
	fi
	@echo ""
	@echo "🎯 Cluster ready! Next steps:"
	@echo "  make deploy    - Deploy application (default: app1)"
	@echo "  make deploy app1  - Deploy basic sample app"
	@echo "  make deploy app2  - Deploy advanced sample app"
	@echo "  make deploy app3  - Deploy multi-service app"
	@echo "  make status    - Check cluster health"
	@echo "  make test      - Run validation tests"
	@echo ""
	@echo "💡 To use kubectl in this session, run:"
	@echo "  export KUBECONFIG=\$$(pwd)/data/kubeconfig/config"
	@echo ""
	@kubectl get nodes

# Handle config arguments as targets to avoid "No rule to make target" errors
minimal simple default:
	@:

down: ## Stop the Kind cluster (preserves data)
	@echo "🛑 Stopping cluster..."
	@./infra/scripts/cluster-down.sh

restart: ## Quick cluster reset for development iteration
	@echo "🔄 Restarting cluster..."
	@./infra/scripts/cluster-restart.sh

##@ Development

prepare: ## Setup development environment (pre-commit, yamllint, hooks)
	@echo "🛠️  Setting up OSDU-CI development environment..."
	@# Install pre-commit if not available
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "Installing pre-commit..."; \
		if command -v pip >/dev/null 2>&1; then \
			pip install pre-commit; \
		elif command -v pipx >/dev/null 2>&1; then \
			pipx install pre-commit; \
		elif command -v brew >/dev/null 2>&1; then \
			brew install pre-commit; \
		else \
			echo "❌ Could not install pre-commit. Please install manually:"; \
			echo "   pip install pre-commit"; \
			exit 1; \
		fi; \
	fi
	@# Install yamllint if not available
	@if ! command -v yamllint >/dev/null 2>&1; then \
		echo "Installing yamllint..."; \
		pip install yamllint; \
	fi
	@# Install pre-commit hooks
	@echo "Installing pre-commit hooks..."
	@pre-commit install
	@echo "✅ Development environment setup complete!"
	@echo ""
	@echo "📋 Available commands:"
	@echo "  make help                    # Show project targets"
	@echo "  pre-commit run --all-files   # Run all linting checks"
	@echo "  yamllint .                   # Check YAML files manually"
	@echo "  make up                      # Start development cluster"
	@echo ""
	@echo "💡 Pre-commit hooks will now run automatically on git commit"

test: ## Run comprehensive cluster validation tests
	$(call check_cluster)
	@echo "🧪 Running comprehensive validation tests..."
	@./infra/scripts/validate-cluster.sh

status: ## Show cluster health and running services
	$(call check_cluster)
	@./infra/scripts/utils.sh status

deploy: ## Deploy application (Usage: make deploy [app1|app2] or APP_DEPLOY=appX)
	$(call check_cluster)
	@echo "📦 Deploying application..."
	@# Determine which app to deploy
	@if [ "$(filter-out deploy,$@)" ]; then \
		APP_NAME="$(filter-out deploy,$@)"; \
	elif [ -n "$(word 2,$(MAKECMDGOALS))" ]; then \
		APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	elif [ -n "${APP_DEPLOY}" ]; then \
		APP_NAME="${APP_DEPLOY}"; \
	else \
		APP_NAME="app1"; \
	fi; \
	echo "🎯 Deploying app: $$APP_NAME"; \
	if [ -f "software/apps/$$APP_NAME/app.yaml" ]; then \
		kubectl apply -f "software/apps/$$APP_NAME/app.yaml"; \
		echo "✅ $$APP_NAME deployed successfully"; \
		echo "📖 See software/apps/$$APP_NAME/README.md for access details"; \
	else \
		echo "❌ App not found: $$APP_NAME"; \
		echo "Available apps:"; \
		ls -1 software/apps/ | grep -v README.md || echo "  No apps found"; \
		exit 1; \
	fi

# Handle app arguments as targets to avoid "No rule to make target" errors
app1 app2 app3:
	@:

##@ Utilities

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
