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
    # Unix uses printf with ANSI color codes
    ECHO := printf
    CYAN := \033[36m
    BOLD := \033[1m
    RESET := \033[0m
endif

# Environment setup
KUBECONFIG_PATH := $(PWD_CMD)$(PATH_SEP)data$(PATH_SEP)kubeconfig$(PATH_SEP)config
export KUBECONFIG := $(KUBECONFIG_PATH)


##@ Setup

help: ## Show this help message
ifeq ($(OS),Windows_NT)
	@powershell -Command "& { \
		Write-Host 'HostK8s - Host-Mode Kubernetes Development Platform'; \
		Write-Host ''; \
		Write-Host 'Usage:'; \
		Write-Host '  make ' -NoNewline; Write-Host '<target>' -ForegroundColor Cyan; \
		Write-Host ''; \
		Write-Host 'Setup' -ForegroundColor White; \
		Write-Host '  ' -NoNewline; Write-Host 'help' -ForegroundColor Cyan -NoNewline; Write-Host '             Show this help message'; \
		Write-Host '  ' -NoNewline; Write-Host 'install' -ForegroundColor Cyan -NoNewline; Write-Host '          Install dependencies and setup environment (Usage: make install [dev])'; \
		Write-Host ''; \
		Write-Host 'Infrastructure' -ForegroundColor White; \
		Write-Host '  ' -NoNewline; Write-Host 'start' -ForegroundColor Cyan -NoNewline; Write-Host '            Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)'; \
		Write-Host '  ' -NoNewline; Write-Host 'stop' -ForegroundColor Cyan -NoNewline; Write-Host '             Stop cluster'; \
		Write-Host '  ' -NoNewline; Write-Host 'up' -ForegroundColor Cyan -NoNewline; Write-Host '               Deploy software stack (Usage: make up [stack-name] - defaults to ''sample'')'; \
		Write-Host '  ' -NoNewline; Write-Host 'down' -ForegroundColor Cyan -NoNewline; Write-Host '             Remove software stack (Usage: make down <stack-name>)'; \
		Write-Host '  ' -NoNewline; Write-Host 'restart' -ForegroundColor Cyan -NoNewline; Write-Host '          Quick cluster reset for development iteration (Usage: make restart [stack-name])'; \
		Write-Host '  ' -NoNewline; Write-Host 'clean' -ForegroundColor Cyan -NoNewline; Write-Host '            Complete cleanup (destroy cluster and data)'; \
		Write-Host '  ' -NoNewline; Write-Host 'status' -ForegroundColor Cyan -NoNewline; Write-Host '           Show cluster health and running services'; \
		Write-Host '  ' -NoNewline; Write-Host 'sync' -ForegroundColor Cyan -NoNewline; Write-Host '             Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])'; \
		Write-Host ''; \
		Write-Host 'Applications' -ForegroundColor White; \
		Write-Host '  ' -NoNewline; Write-Host 'deploy' -ForegroundColor Cyan -NoNewline; Write-Host '           Deploy application (Usage: make deploy [app-name] [namespace] - defaults to ''simple'')'; \
		Write-Host '  ' -NoNewline; Write-Host 'remove' -ForegroundColor Cyan -NoNewline; Write-Host '           Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)'; \
		Write-Host ''; \
		Write-Host 'Development Tools' -ForegroundColor White; \
		Write-Host '  ' -NoNewline; Write-Host 'logs' -ForegroundColor Cyan -NoNewline; Write-Host '             View recent cluster events and logs'; \
		Write-Host '  ' -NoNewline; Write-Host 'build' -ForegroundColor Cyan -NoNewline; Write-Host '            Build and push application from src/ (Usage: make build src/APP_NAME)' \
	}"
else
	@$(ECHO) "HostK8s - Host-Mode Kubernetes Development Platform\n"
	@$(ECHO) "\n"
	@$(ECHO) "Usage:\n"
	@$(ECHO) "  make $(CYAN)<target>$(RESET)\n"
	@$(ECHO) "\n"
	@$(ECHO) "$(BOLD)Setup$(RESET)\n"
	@$(ECHO) "  $(CYAN)help$(RESET)             Show this help message\n"
	@$(ECHO) "  $(CYAN)install$(RESET)          Install dependencies and setup environment (Usage: make install [dev])\n"
	@$(ECHO) "\n"
	@$(ECHO) "$(BOLD)Infrastructure$(RESET)\n"
	@$(ECHO) "  $(CYAN)start$(RESET)            Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)\n"
	@$(ECHO) "  $(CYAN)stop$(RESET)             Stop cluster\n"
	@$(ECHO) "  $(CYAN)up$(RESET)               Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')\n"
	@$(ECHO) "  $(CYAN)down$(RESET)             Remove software stack (Usage: make down <stack-name>)\n"
	@$(ECHO) "  $(CYAN)restart$(RESET)          Quick cluster reset for development iteration (Usage: make restart [stack-name])\n"
	@$(ECHO) "  $(CYAN)clean$(RESET)            Complete cleanup (destroy cluster and data)\n"
	@$(ECHO) "  $(CYAN)status$(RESET)           Show cluster health and running services\n"
	@$(ECHO) "  $(CYAN)sync$(RESET)             Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])\n"
	@$(ECHO) "\n"
	@$(ECHO) "$(BOLD)Applications$(RESET)\n"
	@$(ECHO) "  $(CYAN)deploy$(RESET)           Deploy application (Usage: make deploy [app-name] [namespace] - defaults to 'simple')\n"
	@$(ECHO) "  $(CYAN)remove$(RESET)           Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)\n"
	@$(ECHO) "\n"
	@$(ECHO) "$(BOLD)Development Tools$(RESET)\n"
	@$(ECHO) "  $(CYAN)logs$(RESET)             View recent cluster events and logs\n"
	@$(ECHO) "  $(CYAN)build$(RESET)            Build and push application from src/ (Usage: make build src/APP_NAME)\n"
endif

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
