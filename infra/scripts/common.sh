#!/bin/bash
# infra/scripts/common.sh - Shared utilities for HostK8s scripts
# Source this file from other scripts: source "$(dirname "$0")/common.sh"

set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Colors and formatting
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions with log levels
# LOG_LEVEL can be: debug (default) or info
# debug: shows all messages
# info: shows only info, warn, error (hides debug messages)

log_debug() {
    # Only show debug messages if LOG_LEVEL is not set to info
    if [ "${LOG_LEVEL:-debug}" != "info" ]; then
        echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
    fi
}

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

log_success() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*"
}

log_warn() {
    if [ "${QUIET:-false}" = "true" ]; then
        echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $*"
    else
        echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️${NC} $*"
    fi
}

log_error() {
    if [ "${QUIET:-false}" = "true" ]; then
        echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $*" >&2
    else
        echo -e "${RED}[$(date +'%H:%M:%S')] ❌${NC} $*" >&2
    fi
}

# Convenience aliases for semantic actions
log_start() {
    log_info "$@"
}

log_clean() {
    log_info "$@"
}

log_deploy() {
    log_info "$@"
}

log_section_start() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} ------------------------"
}

log_status() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

log_section_end() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} ------------------------"
}

# Environment setup - source .env if exists
load_environment() {
    if [ -f .env ]; then
        set -a  # Enable allexport mode
        source .env
        set +a  # Disable allexport mode
    fi

    # Set defaults
    export CLUSTER_NAME=${CLUSTER_NAME:-hostk8s}
    export K8S_VERSION=${K8S_VERSION:-v1.33.2}
    export KIND_CONFIG=${KIND_CONFIG:-default}
    export METALLB_ENABLED=${METALLB_ENABLED:-false}
    export INGRESS_ENABLED=${INGRESS_ENABLED:-false}
    export FLUX_ENABLED=${FLUX_ENABLED:-true}
    export KUBECONFIG_PATH="$(pwd)/data/kubeconfig/config"
    export KUBECONFIG="$KUBECONFIG_PATH"
}

# Validation functions
check_cluster() {
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log_error "Cluster not found. Run 'make up' first."
        exit 1
    fi
}

check_cluster_running() {
    check_cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cluster not running. Run 'make up' to start the cluster."
        exit 1
    fi
}

check_dependencies() {
    local missing_tools=()

    for tool in kind kubectl helm docker; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Run 'make install' to install dependencies"
        exit 1
    fi
}

# Common kubectl operations
get_app_label() {
    local app_name="$1"
    local app_type="${2:-app}"  # 'app' for manual, 'application' for GitOps
    echo "osdu-ci.${app_type}=${app_name}"
}

get_deployments_for_app() {
    local app_name="$1"
    local app_type="${2:-app}"
    local label=$(get_app_label "$app_name" "$app_type")
    kubectl get deployments -l "$label" --all-namespaces --no-headers 2>/dev/null || true
}

get_services_for_app() {
    local app_name="$1"
    local app_type="${2:-app}"
    local label=$(get_app_label "$app_name" "$app_type")
    kubectl get services -l "$label" --all-namespaces --no-headers 2>/dev/null || true
}

get_ingress_for_app() {
    local app_name="$1"
    local app_type="${2:-app}"
    local label=$(get_app_label "$app_name" "$app_type")
    kubectl get ingress -l "$label" --all-namespaces --no-headers 2>/dev/null || true
}

# GitOps/Flux helpers
has_flux() {
    kubectl get namespace flux-system >/dev/null 2>&1
}

has_flux_cli() {
    command -v flux >/dev/null 2>&1
}

get_flux_version() {
    if has_flux_cli; then
        flux version 2>/dev/null | head -1 | cut -d' ' -f2 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Argument parsing helpers
parse_make_args() {
    # Extract arguments from MAKECMDGOALS-style input
    # Usage: parse_make_args "$@" --> returns arg after script name
    echo "${2:-}"
}

validate_stamp_arg() {
    local stamp="$1"
    local valid_stamps="sample"  # Add more as they're created

    if [ -n "$stamp" ] && [[ ! " $valid_stamps " =~ " $stamp " ]]; then
        log_error "Unknown stamp: $stamp"
        log_info "Valid stamps: $valid_stamps"
        return 1
    fi
    return 0
}

validate_kind_config_arg() {
    local config="$1"
    local valid_configs="minimal simple default"

    if [ -n "$config" ] && [[ ! " $valid_configs " =~ " $config " ]]; then
        log_error "Unknown config: $config"
        log_info "Valid configs: $valid_configs"
        return 1
    fi
    return 0
}

# App deployment helpers
list_available_apps() {
    find software/apps/ -name "app.yaml" -exec dirname {} \; 2>/dev/null | sed 's|software/apps/||' | sort || echo "  No apps found"
}

validate_app_exists() {
    local app_name="$1"
    if [ ! -f "software/apps/$app_name/app.yaml" ]; then
        log_error "App not found: $app_name"
        log_info "Available apps:"
        list_available_apps | sed 's/^/  /'
        return 1
    fi
    return 0
}

# Service access helpers
get_nodeport_access() {
    local service_line="$1"
    local ports=$(echo "$service_line" | awk '{print $6}')
    local nodeport=$(echo "$ports" | grep -o '[0-9]*:3[0-9]*/' | cut -d: -f2 | cut -d/ -f1)

    case "$nodeport" in
        "30080") echo "http://localhost:8080" ;;
        "30443") echo "https://localhost:8443" ;;
        *) echo "NodePort $nodeport - not mapped to localhost" ;;
    esac
}

get_loadbalancer_access() {
    local service_line="$1"
    local external_ip=$(echo "$service_line" | awk '{print $5}')
    local port=$(echo "$service_line" | awk '{print $6}' | cut -d: -f1)

    if [ "$external_ip" != "<none>" ] && [ "$external_ip" != "<pending>" ]; then
        echo "http://$external_ip:$port"
    else
        echo "$external_ip"
    fi
}

get_ingress_access() {
    local app_name="$1"
    local ingress_line="$2"
    local hosts=$(echo "$ingress_line" | awk '{print $4}')

    if [ "$hosts" = "localhost" ]; then
        case "$app_name" in
            "app1") echo "http://localhost:8080/app1" ;;
            "app2") echo "http://localhost:8080/frontend, /api" ;;
            "app3") echo "http://localhost:8080/app3/frontend, /app3/api" ;;
            *) echo "http://localhost:8080" ;;
        esac
    else
        echo "hosts: $hosts"
    fi
}

# Health check helpers
check_deployment_health() {
    local ready="$1"
    local ready_count=$(echo "$ready" | cut -d/ -f1)
    local total_count=$(echo "$ready" | cut -d/ -f2)
    [ "$ready_count" = "$total_count" ]
}

check_pod_health() {
    local status="$1"
    [ "$status" = "Running" ] || [ "$status" = "Completed" ]
}

check_service_health() {
    local service_line="$1"
    local type=$(echo "$service_line" | awk '{print $3}')
    local external_ip=$(echo "$service_line" | awk '{print $5}')

    if [ "$type" = "LoadBalancer" ] && [ "$external_ip" = "<pending>" ]; then
        return 1
    fi
    return 0
}

# Initialize common environment when sourced
load_environment
