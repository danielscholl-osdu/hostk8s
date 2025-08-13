#!/bin/bash
# infra/scripts/show-help.sh - Display help information for HostK8s

# Colors
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

printf "HostK8s - Host-Mode Kubernetes Development Platform\n"
printf "\n"
printf "Usage:\n"
printf "  make ${CYAN}<target>${RESET}\n"
printf "\n"
printf "${BOLD}Setup${RESET}\n"
printf "  ${CYAN}help${RESET}             Show this help message\n"
printf "  ${CYAN}install${RESET}          Install dependencies and setup environment (Usage: make install [dev])\n"
printf "\n"
printf "${BOLD}Infrastructure${RESET}\n"
printf "  ${CYAN}start${RESET}            Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)\n"
printf "  ${CYAN}stop${RESET}             Stop cluster\n"
printf "  ${CYAN}up${RESET}               Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')\n"
printf "  ${CYAN}down${RESET}             Remove software stack (Usage: make down <stack-name>)\n"
printf "  ${CYAN}restart${RESET}          Quick cluster reset for development iteration (Usage: make restart [stack-name])\n"
printf "  ${CYAN}clean${RESET}            Complete cleanup (destroy cluster and data)\n"
printf "  ${CYAN}status${RESET}           Show cluster health and running services\n"
printf "  ${CYAN}sync${RESET}             Force Flux reconciliation (Usage: make sync [REPO=name] [KUSTOMIZATION=name])\n"
printf "\n"
printf "${BOLD}Applications${RESET}\n"
printf "  ${CYAN}deploy${RESET}           Deploy application (Usage: make deploy [app-name] [namespace] - defaults to 'simple')\n"
printf "  ${CYAN}remove${RESET}           Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)\n"
printf "\n"
printf "${BOLD}Development Tools${RESET}\n"
printf "  ${CYAN}logs${RESET}             View recent cluster events and logs\n"
printf "  ${CYAN}build${RESET}            Build and push application from src/ (Usage: make build src/APP_NAME)\n"