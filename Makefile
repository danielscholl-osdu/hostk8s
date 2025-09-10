# HostK8s - Host-Mode Kubernetes Development Platform
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install start stop up down restart clean status deploy remove sync suspend resume build

# Load .env file if it exists
-include .env
export

# Set UTF-8 encoding for Python scripts on Windows
ifeq ($(OS),Windows_NT)
    export PYTHONIOENCODING := utf-8
endif

# Script routing system - All scripts are Python except install
# No fallback needed since uv is a requirement
define SCRIPT_RUNNER_FUNC
uv run ./infra/scripts/$(1).py
endef

# OS Detection for cross-platform compatibility
ifeq ($(OS),Windows_NT)
    SCRIPT_EXT := .ps1
    # Only used for install script now - all others use uv run
    INSTALL_RUNNER := pwsh -ExecutionPolicy Bypass -NoProfile -File
    PWD_CMD := $$(pwsh -Command "(Get-Location).Path")
    PATH_SEP := \\
    NULL_DEVICE := nul
else
    SCRIPT_EXT := .sh
    INSTALL_RUNNER :=
    PWD_CMD := $$(pwd)
    PATH_SEP := /
    NULL_DEVICE := /dev/null
    # Unix uses printf with ANSI color codes
    ECHO := printf
    CYAN := \033[36m
    BOLD := \033[1m
    RESET := \033[0m
endif

# Install script runner - only used for make install target
# This is the ONLY script that's not Python
SCRIPT_RUNNER := $(INSTALL_RUNNER)

# Environment setup - Cross-platform path resolution
ifeq ($(OS),Windows_NT)
    KUBECONFIG_PATH := data\kubeconfig\config
    export KUBECONFIG := $(shell pwsh -Command "(Get-Location).Path")\$(KUBECONFIG_PATH)
else
    KUBECONFIG_PATH := data/kubeconfig/config
    export KUBECONFIG := $(shell pwd)/$(KUBECONFIG_PATH)
endif


##@ Setup

help: ## Show this help message
ifeq ($(OS),Windows_NT)
	@pwsh -ExecutionPolicy Bypass -File infra/scripts/common.ps1 help
else
	@echo "HostK8s - Host-Mode Kubernetes Development Platform"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
endif

install: ## Install dependencies and setup environment (Usage: make install [dev])
ifeq ($(word 2,$(MAKECMDGOALS)),dev)
	@$(call SCRIPT_RUNNER_FUNC,prepare)
else
	@$(INSTALL_RUNNER) ./infra/scripts/install$(SCRIPT_EXT)
endif

# Handle dev argument as target to avoid "No rule to make target" errors
dev:
	@:

##@ Infrastructure

start: ## Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)
	@$(call SCRIPT_RUNNER_FUNC,cluster-up) $(word 2,$(MAKECMDGOALS))
ifdef SOFTWARE_STACK
ifeq ($(OS),Windows_NT)
	@pwsh -ExecutionPolicy Bypass -File infra/scripts/common.ps1 auto-deploy "$(SOFTWARE_STACK)" "$(SOFTWARE_BUILD)"
else
	@STACK_NAME=$$(echo "$(SOFTWARE_STACK)" | xargs); \
	echo "[Cluster] SOFTWARE_STACK detected: $$STACK_NAME"; \
	BUILD_TARGET=$$(echo "$${SOFTWARE_BUILD:-$$STACK_NAME}" | xargs); \
	if [ -n "$$BUILD_TARGET" ] && [ -d "src/$$BUILD_TARGET" ]; then \
		echo "[Cluster] Auto-building: src/$$BUILD_TARGET"; \
		$(MAKE) build "src/$$BUILD_TARGET"; \
	fi; \
	echo "[Cluster] Auto-deploying stack..."; \
	$(MAKE) up "$$STACK_NAME"
endif
endif

stop: ## Stop cluster
	@$(call SCRIPT_RUNNER_FUNC,cluster-down)

up: ## Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')
	@$(call SCRIPT_RUNNER_FUNC,manage-storage) setup $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),sample)
	@$(call SCRIPT_RUNNER_FUNC,manage-secrets) add $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),sample)
	@$(call SCRIPT_RUNNER_FUNC,deploy-stack) $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),sample)

# Handle arguments as targets to avoid "No rule to make target" errors
minimal:
	@:
simple:
	@:
default:
	@:
sample:
	@:
extension:
	@:
multi-tier:
	@:
%:
	@:

# Handle extension/* patterns
extension/%:
	@:

down: ## Remove software stack (Usage: make down <stack-name>)
	-@$(call SCRIPT_RUNNER_FUNC,manage-secrets) remove "$(word 2,$(MAKECMDGOALS))"
	@$(call SCRIPT_RUNNER_FUNC,deploy-stack) down "$(word 2,$(MAKECMDGOALS))"
	-@$(call SCRIPT_RUNNER_FUNC,manage-storage) cleanup "$(word 2,$(MAKECMDGOALS))"

restart: ## Quick cluster reset for development iteration (Usage: make restart [stack-name])
	@$(call SCRIPT_RUNNER_FUNC,cluster-restart) $(word 2,$(MAKECMDGOALS))

clean: ## Complete cleanup (destroy cluster and data)
	-@$(call SCRIPT_RUNNER_FUNC,cluster-down)
	-@kind delete cluster --name hostk8s
ifeq ($(OS),Windows_NT)
	@pwsh -ExecutionPolicy Bypass -File infra/scripts/common.ps1 clean-data
else
	@echo "[$$(date '+%H:%M:%S')] [Clean] Cleaning data directory and persistent volumes..."
	-@rm -rf data/
	@echo "[$$(date '+%H:%M:%S')] [Clean] Removing Docker volumes..."
	-@docker volume rm hostk8s-pv-data >$(NULL_DEVICE) 2>&1 || true
	@echo "[$$(date '+%H:%M:%S')] [Clean] Data cleanup completed"
endif

status: ## Show cluster health and running services
	@$(call SCRIPT_RUNNER_FUNC,cluster-status)

sync: ## Force Flux reconciliation (Usage: make sync [stack-name] or REPO=name/KUSTOMIZATION=name make sync)
ifdef REPO
	@$(call SCRIPT_RUNNER_FUNC,flux-sync) --repo "$(REPO)"
else ifdef KUSTOMIZATION
	@$(call SCRIPT_RUNNER_FUNC,flux-sync) --kustomization "$(KUSTOMIZATION)"
else ifneq ($(word 2,$(MAKECMDGOALS)),)
	@$(call SCRIPT_RUNNER_FUNC,flux-sync) --stack "$(word 2,$(MAKECMDGOALS))"
else
	@$(call SCRIPT_RUNNER_FUNC,flux-sync)
endif

suspend: ## Suspend GitOps reconciliation (pause all GitRepository sources)
	@$(call SCRIPT_RUNNER_FUNC,flux-suspend) suspend

resume: ## Resume GitOps reconciliation (restore all GitRepository sources)
	@$(call SCRIPT_RUNNER_FUNC,flux-suspend) resume

##@ Applications

deploy: ## Deploy application (Usage: make deploy [app-name] [namespace] - defaults to SOFTWARE_APP or 'simple')
	@$(call SCRIPT_RUNNER_FUNC,deploy-app) $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),$(if $(SOFTWARE_APP),$(SOFTWARE_APP),simple)) $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),default)

remove: ## Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)
	@$(call SCRIPT_RUNNER_FUNC,deploy-app) remove "$(word 2,$(MAKECMDGOALS))" $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),$(if $(NAMESPACE),$(NAMESPACE),default))

# Handle app and namespace arguments as targets to avoid "No rule to make target" errors
%:
	@:

# Handle src/* arguments as targets to avoid "No rule to make target" errors
src/%:
	@:


##@ Development Tools


build: ## Build and push application from src/ (Usage: make build [src/APP_NAME] - defaults to SOFTWARE_BUILD or 'src/sample-app')
	@$(call SCRIPT_RUNNER_FUNC,build) "$(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),$(if $(SOFTWARE_BUILD),src/$(SOFTWARE_BUILD),src/sample-app))"
