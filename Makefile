# HostK8s - Host-Mode Kubernetes Development Platform
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install start stop up down restart clean status deploy remove sync suspend resume logs build

# OS Detection for cross-platform script execution
ifeq ($(OS),Windows_NT)
    SCRIPT_EXT := .ps1
    SCRIPT_RUNNER := pwsh -ExecutionPolicy Bypass -NoProfile -File
    PWD_CMD := $$(pwsh -Command "(Get-Location).Path")
    PATH_SEP := \\
else
    SCRIPT_EXT := .sh
    SCRIPT_RUNNER :=
    PWD_CMD := $$(pwd)
    PATH_SEP := /
    # Unix uses printf with ANSI color codes
    ECHO := printf
    CYAN := \033[36m
    BOLD := \033[1m
    RESET := \033[0m
endif

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
	@$(SCRIPT_RUNNER) ./infra/scripts/show-help$(SCRIPT_EXT)

install: ## Install dependencies and setup environment (Usage: make install [dev])
ifeq ($(word 2,$(MAKECMDGOALS)),dev)
	@$(SCRIPT_RUNNER) ./infra/scripts/prepare$(SCRIPT_EXT)
else
	@$(SCRIPT_RUNNER) ./infra/scripts/install$(SCRIPT_EXT)
endif

# Handle dev argument as target to avoid "No rule to make target" errors
dev:
	@:

##@ Infrastructure

start: ## Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-up$(SCRIPT_EXT) $(word 2,$(MAKECMDGOALS))

stop: ## Stop cluster
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-down$(SCRIPT_EXT)

up: ## Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')
	@$(SCRIPT_RUNNER) ./infra/scripts/manage-secrets$(SCRIPT_EXT) add $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),sample) 2>/dev/null || true
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-stack$(SCRIPT_EXT) $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),sample)

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
	@$(SCRIPT_RUNNER) ./infra/scripts/manage-secrets$(SCRIPT_EXT) remove "$(word 2,$(MAKECMDGOALS))" 2>/dev/null || true
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-stack$(SCRIPT_EXT) down "$(word 2,$(MAKECMDGOALS))"

restart: ## Quick cluster reset for development iteration (Usage: make restart [stack-name])
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-restart$(SCRIPT_EXT) $(word 2,$(MAKECMDGOALS))

clean: ## Complete cleanup (destroy cluster and data)
ifeq ($(OS),Windows_NT)
	@pwsh -ExecutionPolicy Bypass -NoProfile -File ./infra/scripts/cluster-down.ps1 2>nul || echo ""
	@kind delete cluster --name hostk8s 2>nul || echo ""
	@powershell -Command "Remove-Item -Recurse -Force data -ErrorAction SilentlyContinue" 2>nul || echo ""
else
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-down$(SCRIPT_EXT) 2>/dev/null || true
	@kind delete cluster --name hostk8s 2>/dev/null || true
	@rm -rf data/ 2>/dev/null || true
endif

status: ## Show cluster health and running services
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-status$(SCRIPT_EXT)

sync: ## Force Flux reconciliation (Usage: make sync [stack-name] or REPO=name/KUSTOMIZATION=name make sync)
ifdef REPO
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT) --repo "$(REPO)"
else ifdef KUSTOMIZATION
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT) --kustomization "$(KUSTOMIZATION)"
else ifneq ($(word 2,$(MAKECMDGOALS)),)
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT) --stack "$(word 2,$(MAKECMDGOALS))"
else
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT)
endif

suspend: ## Suspend GitOps reconciliation (pause all GitRepository sources)
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-suspend$(SCRIPT_EXT) suspend

resume: ## Resume GitOps reconciliation (restore all GitRepository sources)
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-suspend$(SCRIPT_EXT) resume

##@ Applications

deploy: ## Deploy application (Usage: make deploy [app-name] [namespace] - defaults to 'simple')
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-app$(SCRIPT_EXT) $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),simple) $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),default)

remove: ## Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-app$(SCRIPT_EXT) remove "$(word 2,$(MAKECMDGOALS))" $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),$(if $(NAMESPACE),$(NAMESPACE),default))

# Handle app and namespace arguments as targets to avoid "No rule to make target" errors
%:
	@:

# Handle src/* arguments as targets to avoid "No rule to make target" errors
src/%:
	@:


##@ Development Tools

logs: ## View recent cluster events and logs
	@$(SCRIPT_RUNNER) ./infra/scripts/utils$(SCRIPT_EXT) logs $(filter-out logs,$(MAKECMDGOALS))

build: ## Build and push application from src/ (Usage: make build src/APP_NAME)
	@$(SCRIPT_RUNNER) ./infra/scripts/build$(SCRIPT_EXT) "$(word 2,$(MAKECMDGOALS))"
