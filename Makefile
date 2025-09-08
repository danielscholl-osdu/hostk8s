# HostK8s - Host-Mode Kubernetes Development Platform
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install start stop up down restart clean status deploy remove sync suspend resume logs build

# Python Detection for uv-based scripts
ifeq ($(OS),Windows_NT)
    UV_AVAILABLE := $(shell where uv 2>NUL)
    # Set UTF-8 encoding for Python scripts on Windows
    export PYTHONIOENCODING := utf-8
else
    UV_AVAILABLE := $(shell command -v uv 2>/dev/null)
endif
PYTHON_AVAILABLE := $(if $(UV_AVAILABLE),true,false)

# Script routing system - Python takes priority if available AND uv is installed
ifeq ($(OS),Windows_NT)
define SCRIPT_RUNNER_FUNC
$(if $(and $(UV_AVAILABLE),$(shell powershell -Command "if (Test-Path '.\infra\scripts\$(1).py') { Write-Host 'exists' }")),uv run ./infra/scripts/$(1).py,$(call SHELL_SCRIPT_FUNC,$(1)))
endef
else
define SCRIPT_RUNNER_FUNC
$(if $(and $(UV_AVAILABLE),$(shell test -f ./infra/scripts/$(1).py && echo "exists")),uv run ./infra/scripts/$(1).py,$(call SHELL_SCRIPT_FUNC,$(1)))
endef
endif

# OS Detection for cross-platform shell script execution
ifeq ($(OS),Windows_NT)
    SCRIPT_EXT := .ps1
    SHELL_RUNNER := pwsh -ExecutionPolicy Bypass -NoProfile -File
    PWD_CMD := $$(pwsh -Command "(Get-Location).Path")
    PATH_SEP := \\
else
    SCRIPT_EXT := .sh
    SHELL_RUNNER :=
    PWD_CMD := $$(pwd)
    PATH_SEP := /
    # Unix uses printf with ANSI color codes
    ECHO := printf
    CYAN := \033[36m
    BOLD := \033[1m
    RESET := \033[0m
endif

# Shell script fallback function
define SHELL_SCRIPT_FUNC
$(SHELL_RUNNER) ./infra/scripts/$(1)$(SCRIPT_EXT)
endef

# Backwards compatibility - SCRIPT_RUNNER for scripts not yet migrated
SCRIPT_RUNNER := $(SHELL_RUNNER)

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
	@echo "HostK8s - Host-Mode Kubernetes Development Platform"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

install: ## Install dependencies and setup environment (Usage: make install [dev])
ifeq ($(word 2,$(MAKECMDGOALS)),dev)
	@$(call SCRIPT_RUNNER_FUNC,prepare)
else
	@$(SCRIPT_RUNNER) ./infra/scripts/install$(SCRIPT_EXT)
endif

# Handle dev argument as target to avoid "No rule to make target" errors
dev:
	@:

##@ Infrastructure

start: ## Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)
	@$(call SCRIPT_RUNNER_FUNC,cluster-up) $(word 2,$(MAKECMDGOALS))

stop: ## Stop cluster
	@$(call SCRIPT_RUNNER_FUNC,cluster-down)

up: ## Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')
	@$(call SCRIPT_RUNNER_FUNC,manage-secrets) add $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),sample) 2>/dev/null || true
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
	@$(call SCRIPT_RUNNER_FUNC,manage-secrets) remove "$(word 2,$(MAKECMDGOALS))" 2>/dev/null || true
	@$(call SCRIPT_RUNNER_FUNC,deploy-stack) down "$(word 2,$(MAKECMDGOALS))"

restart: ## Quick cluster reset for development iteration (Usage: make restart [stack-name])
	@$(call SCRIPT_RUNNER_FUNC,cluster-restart) $(word 2,$(MAKECMDGOALS))

clean: ## Complete cleanup (destroy cluster and data)
	@$(call SCRIPT_RUNNER_FUNC,cluster-down) 2>/dev/null || true
	@kind delete cluster --name hostk8s 2>/dev/null || true
ifeq ($(OS),Windows_NT)
	@powershell -Command "Remove-Item -Recurse -Force data -ErrorAction SilentlyContinue" 2>nul || echo ""
else
	@rm -rf data/ 2>/dev/null || true
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

deploy: ## Deploy application (Usage: make deploy [app-name] [namespace] - defaults to 'simple')
	@$(call SCRIPT_RUNNER_FUNC,deploy-app) $(if $(word 2,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),simple) $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),default)

remove: ## Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)
	@$(call SCRIPT_RUNNER_FUNC,deploy-app) remove "$(word 2,$(MAKECMDGOALS))" $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),$(if $(NAMESPACE),$(NAMESPACE),default))

# Handle app and namespace arguments as targets to avoid "No rule to make target" errors
%:
	@:

# Handle src/* arguments as targets to avoid "No rule to make target" errors
src/%:
	@:


##@ Development Tools

logs: ## View recent cluster events and logs (Use kubectl directly or make status for comprehensive info)
	@echo "Use 'make status' for comprehensive cluster information, or kubectl directly:"
	@echo "  kubectl get events --sort-by=.metadata.creationTimestamp"
	@echo "  kubectl logs -f deployment/my-app"

build: ## Build and push application from src/ (Usage: make build src/APP_NAME)
	@$(call SCRIPT_RUNNER_FUNC,build) "$(word 2,$(MAKECMDGOALS))"
