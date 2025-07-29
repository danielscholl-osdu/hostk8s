# OSDU-CI Host-Mode Kubernetes Development Environment
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

##@ Cluster Operations

up: install ## Start cluster with dependencies check (Usage: make up [minimal|simple|default|sample])
	@echo "🚀 Starting cluster..."
	@# Determine if argument is a Kind config or GitOps stamp
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "sample" ] || [ "$$ARG" = "osdu-ci" ]; then \
		echo "🎯 Detected GitOps stamp: $$ARG"; \
		FLUX_ENABLED=true GITOPS_STAMP="$$ARG" ./infra/scripts/cluster-up.sh; \
	elif [ "$$ARG" = "minimal" ] || [ "$$ARG" = "simple" ] || [ "$$ARG" = "default" ]; then \
		echo "🎯 Detected Kind config: $$ARG"; \
		KIND_CONFIG="$$ARG" ./infra/scripts/cluster-up.sh; \
	elif [ -n "$$ARG" ]; then \
		echo "❌ Unknown argument: $$ARG"; \
		echo "Valid options: minimal, simple, default (Kind configs) | sample, osdu-ci (GitOps stamps)"; \
		exit 1; \
	else \
		KIND_CONFIG=${KIND_CONFIG} ./infra/scripts/cluster-up.sh; \
	fi
	@echo ""
	@echo "💡 export KUBECONFIG=\$$(pwd)/data/kubeconfig/config"
	@echo ""
	@kubectl get nodes

# Handle arguments as targets to avoid "No rule to make target" errors
minimal simple default sample osdu-ci:
	@:

down: ## Stop the Kind cluster (preserves data)
	@echo "🛑 Stopping cluster..."
	@./infra/scripts/cluster-down.sh

restart: ## Quick cluster reset for development iteration (Usage: make restart [sample])
	@echo "🔄 Restarting cluster..."
	@# Determine if argument is a GitOps stamp
	@ARG="$(word 2,$(MAKECMDGOALS))"; \
	if [ "$$ARG" = "sample" ] || [ "$$ARG" = "osdu-ci" ]; then \
		echo "🎯 Restarting with GitOps stamp: $$ARG"; \
		FLUX_ENABLED=true GITOPS_STAMP="$$ARG" ./infra/scripts/cluster-restart.sh; \
	elif [ -n "$$ARG" ]; then \
		echo "❌ Unknown stamp: $$ARG"; \
		echo "Valid stamps: sample, osdu-ci"; \
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
	@if [ ! -f "$(KUBECONFIG_PATH)" ]; then \
		echo "⚠️  No cluster found. Run 'make up' to start a cluster."; \
		exit 0; \
	fi
	@export KUBECONFIG="$(KUBECONFIG_PATH)"; \
	if ! kubectl cluster-info >/dev/null 2>&1; then \
		echo "⚠️  Cluster not running. Run 'make up' to start the cluster."; \
		exit 0; \
	fi; \
	echo "💡 export KUBECONFIG=\$$(pwd)/data/kubeconfig/config"; \
	echo; \
	if kubectl get namespace flux-system >/dev/null 2>&1; then \
		if command -v flux >/dev/null 2>&1; then \
			flux_version=$$(flux version 2>/dev/null | head -1 | cut -d' ' -f2 || echo "unknown"); \
			echo "$$(date +'[%H:%M:%S]') === GitOps Status (Flux:$$flux_version) ==="; \
		else \
			echo "$$(date +'[%H:%M:%S]') === GitOps Status (Flux:unknown) ==="; \
		fi; \
		if command -v flux >/dev/null 2>&1; then \
			flux get sources git 2>/dev/null | grep -v "^NAME" | while IFS=$$'\t' read -r name revision suspended ready message; do \
				repo_url=$$(kubectl get gitrepository.source.toolkit.fluxcd.io $$name -n flux-system -o jsonpath='{.spec.url}' 2>/dev/null || echo "unknown"); \
				branch=$$(kubectl get gitrepository.source.toolkit.fluxcd.io $$name -n flux-system -o jsonpath='{.spec.ref.branch}' 2>/dev/null || echo "unknown"); \
				echo "📁 Repository: $$name"; \
				echo "   URL: $$repo_url"; \
				echo "   Branch: $$branch"; \
				echo "   Revision: $$revision"; \
				echo "   Ready: $$ready"; \
				echo "   Suspended: $$suspended"; \
				[ "$$message" != "-" ] && echo "   Message: $$message"; \
				echo; \
			done; \
			flux get kustomizations 2>/dev/null | grep -v "^NAME" | grep -v "^[[:space:]]*$$" | while IFS=$$'\t' read -r name revision suspended ready message; do \
				name_trimmed=$$(echo "$$name" | tr -d ' '); \
				[ -z "$$name_trimmed" ] && continue; \
				source_ref=$$(kubectl get kustomization.kustomize.toolkit.fluxcd.io $$name -n flux-system -o jsonpath='{.spec.sourceRef.name}' 2>/dev/null || echo "unknown"); \
				suspended_trim=$$(echo "$$suspended" | tr -d ' '); \
				ready_trim=$$(echo "$$ready" | tr -d ' '); \
				if [ "$$suspended_trim" = "True" ]; then \
					status_icon="[PAUSED]"; \
				elif [ "$$ready_trim" = "True" ]; then \
					status_icon="[OK]"; \
				elif [ "$$ready_trim" = "False" ]; then \
					status_icon="[FAIL]"; \
				else \
					status_icon="[...]"; \
				fi; \
				echo "$$status_icon Kustomization: $$name"; \
				echo "   Source: $$source_ref"; \
				echo "   Revision: $$revision"; \
				echo "   Ready: $$ready"; \
				echo "   Suspended: $$suspended"; \
				[ "$$message" != "-" ] && [ "$$message" != "" ] && echo "   Message: $$message"; \
				echo; \
			done; \
		else \
			echo "flux CLI not available - showing basic status:"; \
			kubectl get gitrepositories.source.toolkit.fluxcd.io -A --no-headers 2>/dev/null | while read -r ns name ready status age; do \
				repo_url=$$(kubectl get gitrepository.source.toolkit.fluxcd.io $$name -n $$ns -o jsonpath='{.spec.url}' 2>/dev/null || echo "unknown"); \
				echo "Repository: $$name ($$repo_url)"; \
				echo "Ready: $$ready"; \
			done; \
		fi; \
	fi; \
	gitops_apps=$$(kubectl get deployments -l osdu-ci.application --all-namespaces -o jsonpath='{.items[*].metadata.labels.osdu-ci\.application}' 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' '); \
	if [ -n "$$gitops_apps" ]; then \
		echo "$$(date +'[%H:%M:%S]') === GitOps Applications ==="; \
		ingress_controller_ready=$$(kubectl get deployment ingress-nginx-controller -n ingress-nginx --no-headers 2>/dev/null | awk '{ready=$$2; split(ready,a,"/"); if(a[1]==a[2] && a[1]>0) print "ready"; else print "not ready"}' || echo "not found"); \
		if [ "$$ingress_controller_ready" = "ready" ]; then \
			echo "🌐 Ingress Controller: ingress-nginx (Ready ✅)"; \
			echo "   Access: http://localhost:8080, https://localhost:8443"; \
		else \
			echo "🌐 Ingress Controller: ingress-nginx ($$ingress_controller_ready ⚠️)"; \
		fi; \
		echo; \
		for app in $$gitops_apps; do \
			echo "📱 GitOps Application: $$app"; \
			kubectl get deployments -l osdu-ci.application=$$app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready up total age; do \
				echo "   Deployment: $$name ($$ready ready, $$ns namespace)"; \
			done; \
			kubectl get services -l osdu-ci.application=$$app --all-namespaces --no-headers 2>/dev/null | while read -r ns name type cluster_ip external_ip ports age; do \
				echo "   Service: $$name ($$type, $$ns namespace)"; \
			done; \
			kubectl get ingress -l osdu-ci.application=$$app --all-namespaces --no-headers 2>/dev/null | while read -r ns name class hosts address ports age; do \
				if [ "$$hosts" = "localhost" ]; then \
					path=$$(kubectl get ingress $$name -n $$ns -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null); \
					if [ "$$path" = "/" ]; then \
						echo "   Access: http://localhost:8080/ ($$name ingress)"; \
					else \
						echo "   Access: http://localhost:8080$$path ($$name ingress)"; \
					fi; \
				else \
					echo "   Ingress: $$name (hosts: $$hosts)"; \
				fi; \
			done; \
			echo; \
		done; \
	fi; \
	deployed_apps=$$(kubectl get all -l osdu-ci.app --all-namespaces -o jsonpath='{.items[*].metadata.labels.osdu-ci\.app}' 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' '); \
	if [ -n "$$deployed_apps" ]; then \
		echo "$$(date +'[%H:%M:%S]') === Manual Deployed Apps ==="; \
		for app in $$deployed_apps; do \
			echo "📱 $$app"; \
			kubectl get deployments -l osdu-ci.app=$$app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready up total age; do \
				echo "   Deployment: $$name ($$ready ready, $$ns namespace)"; \
			done; \
			kubectl get services -l osdu-ci.app=$$app --all-namespaces --no-headers 2>/dev/null | while read -r ns name type cluster_ip external_ip ports age; do \
				if [ "$$type" = "NodePort" ]; then \
					nodeport=$$(echo "$$ports" | grep -o '[0-9]*:3[0-9]*/' | cut -d: -f2 | cut -d/ -f1); \
					if [ "$$nodeport" = "30080" ]; then \
						echo "   Service: $$name ($$type, http://localhost:8080)"; \
					elif [ "$$nodeport" = "30443" ]; then \
						echo "   Service: $$name ($$type, https://localhost:8443)"; \
					else \
						echo "   Service: $$name ($$type, NodePort $$nodeport - not mapped to localhost)"; \
					fi; \
				elif [ "$$type" = "LoadBalancer" ]; then \
					if [ "$$external_ip" != "<none>" ] && [ "$$external_ip" != "<pending>" ]; then \
						port=$$(echo "$$ports" | cut -d: -f1); \
						echo "   Service: $$name ($$type, http://$$external_ip:$$port)"; \
					else \
						echo "   Service: $$name ($$type, $$external_ip)"; \
					fi; \
				elif [ "$$type" = "ClusterIP" ]; then \
					echo "   Service: $$name ($$type, internal only)"; \
				else \
					echo "   Service: $$name ($$type)"; \
				fi; \
			done; \
			kubectl get ingress -l osdu-ci.app=$$app --all-namespaces --no-headers 2>/dev/null | while read -r ns name class hosts address ports age; do \
				if [ "$$hosts" = "localhost" ]; then \
					paths=$$(kubectl get ingress $$name -n $$ns -o jsonpath='{.spec.rules[0].http.paths[*].path}' 2>/dev/null); \
					if [ "$$app" = "app1" ]; then \
						echo "   Ingress: $$name (http://localhost:8080/app1)"; \
					elif [ "$$app" = "app2" ]; then \
						echo "   Ingress: $$name (http://localhost:8080/frontend, /api)"; \
					elif [ "$$app" = "app3" ]; then \
						echo "   Ingress: $$name (http://localhost:8080/app3/frontend, /app3/api)"; \
					else \
						echo "   Ingress: $$name (http://localhost:8080)"; \
					fi; \
				else \
					echo "   Ingress: $$name (hosts: $$hosts)"; \
				fi; \
			done; \
			echo; \
		done; \
		echo "$$(date +'[%H:%M:%S]') === Health Check ==="; \
		issues_found=0; \
		kubectl get services -l osdu-ci.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name type cluster_ip external_ip ports age; do \
			if [ "$$type" = "LoadBalancer" ] && [ "$$external_ip" = "<pending>" ]; then \
				echo "⚠️  LoadBalancer $$name is pending (MetalLB not installed?)"; \
				exit 1; \
			fi; \
		done && \
		kubectl get deployments -l osdu-ci.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready up total age; do \
			ready_count=$$(echo "$$ready" | cut -d/ -f1); \
			total_count=$$(echo "$$ready" | cut -d/ -f2); \
			if [ "$$ready_count" != "$$total_count" ]; then \
				echo "⚠️  Deployment $$name not fully ready ($$ready_count/$$total_count)"; \
				exit 1; \
			fi; \
		done && \
		kubectl get pods -l osdu-ci.app --all-namespaces --no-headers 2>/dev/null | while read -r ns name ready status restarts age; do \
			if [ "$$status" != "Running" ] && [ "$$status" != "Completed" ]; then \
				echo "⚠️  Pod $$name in $$status state"; \
				exit 1; \
			fi; \
		done || issues_found=1; \
		if [ "$$issues_found" = "0" ]; then \
			echo "✅ All deployed apps are healthy"; \
		fi; \
		echo; \
	fi; \
	echo "$$(date +'[%H:%M:%S]') === Cluster Status ==="; \
	kubectl get nodes

sync: ## Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])
	$(call check_cluster)
	@echo "🔄 Forcing Flux reconciliation..."
	@if [ -n "$(REPO)" ]; then \
		echo "📁 Syncing GitRepository: $(REPO)"; \
		flux reconcile source git $(REPO) || echo "❌ Failed to sync $(REPO)"; \
	elif [ -n "$(KUSTOMIZATION)" ]; then \
		echo "⚙️  Syncing Kustomization: $(KUSTOMIZATION)"; \
		flux reconcile kustomization $(KUSTOMIZATION) || echo "❌ Failed to sync $(KUSTOMIZATION)"; \
	else \
		echo "📁 Syncing all GitRepositories (Flux will auto-reconcile kustomizations)..."; \
		git_repos=$$(flux get sources git --no-header 2>/dev/null | awk '{print $$1}'); \
		for repo in $$git_repos; do \
			echo "  → Syncing $$repo"; \
			flux reconcile source git $$repo || echo "  ❌ Failed to sync $$repo"; \
		done; \
	fi
	@echo "✅ Sync complete! Run 'make status' to check results."

##@ Tools

deploy: ## Deploy application (Usage: make deploy [sample/app1|sample/app2|sample/app3])
	$(call check_cluster)
	@echo "📦 Deploying application..."
	@# Determine which app to deploy
	@if [ -n "$(word 2,$(MAKECMDGOALS))" ]; then \
		APP_NAME="$(word 2,$(MAKECMDGOALS))"; \
	else \
		APP_NAME="sample/app1"; \
	fi; \
	echo "🎯 Deploying app: $$APP_NAME"; \
	if [ -f "software/apps/$$APP_NAME/app.yaml" ]; then \
		kubectl apply -f "software/apps/$$APP_NAME/app.yaml"; \
		echo "✅ $$APP_NAME deployed successfully"; \
		echo "📖 See software/apps/$$APP_NAME/README.md for access details"; \
	else \
		echo "❌ App not found: $$APP_NAME"; \
		echo "Available apps:"; \
		find software/apps/ -name "app.yaml" -exec dirname {} \; | sed 's|software/apps/||' | sort || echo "  No apps found"; \
		exit 1; \
	fi

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
	$(call check_cluster)
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "Usage: make build src/APP_NAME"; \
		echo ""; \
		echo "Available applications:"; \
		find src/ -name "docker-compose.yml" -exec dirname {} \; | sort || echo "  No applications found in src/"; \
		exit 1; \
	fi
	@APP_PATH="$(word 2,$(MAKECMDGOALS))"; \
	if [ ! -d "$$APP_PATH" ]; then \
		echo "❌ Directory not found: $$APP_PATH"; \
		echo "Available applications:"; \
		find src/ -name "docker-compose.yml" -exec dirname {} \; | sort || echo "  No applications found in src/"; \
		exit 1; \
	fi; \
	if [ ! -f "$$APP_PATH/docker-compose.yml" ]; then \
		echo "❌ No docker-compose.yml found in $$APP_PATH"; \
		echo "Expected: $$APP_PATH/docker-compose.yml"; \
		exit 1; \
	fi; \
	echo "🏗️ Building application: $$APP_PATH"; \
	cd "$$APP_PATH" && \
	export BUILD_DATE=$$(date -u +"%Y-%m-%dT%H:%M:%SZ") && \
	export BUILD_VERSION="1.0.0" && \
	echo "📅 Build date: $$BUILD_DATE" && \
	echo "🏷️ Version: $$BUILD_VERSION" && \
	docker compose build && \
	echo "📤 Pushing to registry..." && \
	docker compose push && \
	echo "✅ Build and push complete"; \
	echo ""; \
	echo "Next steps:"; \
	APP_NAME=$$(basename "$$APP_PATH"); \
	echo "1. Deploy: make deploy sample/$$APP_NAME"; \
	echo "2. Status: make status"; \
	echo "3. Access: check software/apps/sample/$$APP_NAME/README.md"
