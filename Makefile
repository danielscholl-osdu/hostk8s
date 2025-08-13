# HostK8s - Host-Mode Kubernetes Development Platform
# Standard Make targets following common conventions

.DEFAULT_GOAL := help
.PHONY: help install start stop up down restart clean status deploy remove sync logs build

# OS Detection for cross-platform script execution
ifeq ($(OS),Windows_NT)
    SCRIPT_EXT := .ps1
    SCRIPT_RUNNER := powershell.exe -ExecutionPolicy Bypass -NoProfile -File
    PWD_CMD := $$(powershell -Command "(Get-Location).Path")
    PATH_SEP := \\
else
    SCRIPT_EXT := .sh
    SCRIPT_RUNNER := 
    PWD_CMD := $$(pwd)
    PATH_SEP := /
endif

# Environment setup
KUBECONFIG_PATH := $(PWD_CMD)$(PATH_SEP)data$(PATH_SEP)kubeconfig$(PATH_SEP)config
export KUBECONFIG := $(KUBECONFIG_PATH)


##@ Setup

help: ## Show this help message
	@$(SCRIPT_RUNNER) ./infra/scripts/show-help$(SCRIPT_EXT)

install: ## Install dependencies and setup environment (Usage: make install [dev])
ifeq ($(word 2,$(MAKECMDGOALS)),dev)
	@echo "Setting up development environment..."
	@$(SCRIPT_RUNNER) ./infra/scripts/prepare$(SCRIPT_EXT)
else
	@echo "Installing local dependencies..."
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
	@$(SCRIPT_RUNNER) ./infra/scripts/deploy-stack$(SCRIPT_EXT) down "$(word 2,$(MAKECMDGOALS))"

restart: ## Quick cluster reset for development iteration (Usage: make restart [stack-name])
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-restart$(SCRIPT_EXT) $(word 2,$(MAKECMDGOALS))

clean: ## Complete cleanup (destroy cluster and data)
ifeq ($(OS),Windows_NT)
	@powershell -Command "try { & $(SCRIPT_RUNNER) ./infra/scripts/cluster-down$(SCRIPT_EXT) 2>$$null } catch {}; try { kind delete cluster --name hostk8s 2>$$null } catch {}; try { Remove-Item -Recurse -Force data -ErrorAction SilentlyContinue } catch {}; try { docker system prune -f 2>$$null } catch {}"
else
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-down$(SCRIPT_EXT) 2>/dev/null || true
	@kind delete cluster --name hostk8s 2>/dev/null || true
	@rm -rf data/ 2>/dev/null || true
	@docker system prune -f >/dev/null 2>&1 || true
endif

status: ## Show cluster health and running services
	@$(SCRIPT_RUNNER) ./infra/scripts/cluster-status$(SCRIPT_EXT)

sync: ## Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])
ifdef REPO
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT) --repo "$(REPO)"
else ifdef KUSTOMIZATION
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT) --kustomization "$(KUSTOMIZATION)"
else
	@$(SCRIPT_RUNNER) ./infra/scripts/flux-sync$(SCRIPT_EXT)
endif

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
