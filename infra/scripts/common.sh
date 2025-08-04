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
    export FLUX_ENABLED=${FLUX_ENABLED:-false}
    export PACKAGE_MANAGER=${PACKAGE_MANAGER:-}
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
    echo "hostk8s.${app_type}=${app_name}"
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

# Addon detection functions
has_metallb() {
    kubectl get namespace metallb-system >/dev/null 2>&1
}

has_ingress() {
    kubectl get namespace ingress-nginx >/dev/null 2>&1
}

# Argument parsing helpers
parse_make_args() {
    # Extract arguments from MAKECMDGOALS-style input
    # Usage: parse_make_args "$@" --> returns arg after script name
    echo "${2:-}"
}

validate_stack_arg() {
    local stack="$1"
    local valid_stacks="sample sample-stack"  # Add more as they're created

    if [ -n "$stack" ] && [[ ! " $valid_stacks " =~ " $stack " ]]; then
        log_error "Unknown stack: $stack"
        log_info "Valid stacks: $valid_stacks"
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
    local ns=$(echo "$ingress_line" | awk '{print $1}')
    local name=$(echo "$ingress_line" | awk '{print $2}')
    local hosts=$(echo "$ingress_line" | awk '{print $4}')

    if [ "$hosts" = "localhost" ]; then
        # Dynamically get the path from the ingress resource
        local path=$(kubectl get ingress "$name" -n "$ns" -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)
        if [ -n "$path" ] && [ "$path" != "/" ]; then
            # Clean up nginx rewrite patterns for user-friendly display
            # Convert "/sample/frontend(/|$)(.*)" to "/sample/frontend"
            local clean_path=$(echo "$path" | sed 's/([^)]*)//g')
            echo "http://localhost:8080$clean_path"
        else
            echo "http://localhost:8080"
        fi
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

# Cross-platform sed operations
# Usage: cross_platform_sed_inplace "s/old/new/g" "filepath"
# Returns: 0 on success, 1 on failure
cross_platform_sed_inplace() {
    local pattern="$1"
    local file="$2"

    # Validate inputs
    if [[ -z "$pattern" || -z "$file" ]]; then
        log_error "cross_platform_sed_inplace: pattern and file are required"
        return 1
    fi

    # Check if file exists and is writable
    if [[ ! -f "$file" ]]; then
        log_error "cross_platform_sed_inplace: file does not exist: $file"
        return 1
    fi

    if [[ ! -w "$file" ]]; then
        log_error "cross_platform_sed_inplace: file is not writable: $file"
        return 1
    fi

    # Perform sed operation with error checking
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed syntax (requires empty string after -i)
        if ! sed -i '' "$pattern" "$file" 2>/dev/null; then
            log_error "cross_platform_sed_inplace: sed operation failed on $file"
            return 1
        fi
    else
        # Linux sed syntax
        if ! sed -i "$pattern" "$file" 2>/dev/null; then
            log_error "cross_platform_sed_inplace: sed operation failed on $file"
            return 1
        fi
    fi

    return 0
}

# Update environment file with worktree-specific values
# Usage: update_env_file "/path/to/.env" "cluster_name" "git_user" "worktree_name"
# Returns: 0 on success, 1 on failure
update_env_file() {
    local env_file="$1"
    local cluster_name="$2"
    local git_user="$3"
    local worktree_name="$4"

    # Validate inputs
    if [[ -z "$env_file" || -z "$cluster_name" || -z "$git_user" || -z "$worktree_name" ]]; then
        log_error "update_env_file: all parameters are required"
        return 1
    fi

    # Validate file exists
    if [[ ! -f "$env_file" ]]; then
        log_error "update_env_file: environment file does not exist: $env_file"
        return 1
    fi

    log_debug "Updating environment file: ${env_file}"

    # Update CLUSTER_NAME (handle both commented and uncommented lines)
    cross_platform_sed_inplace "s/^# *CLUSTER_NAME=.*/CLUSTER_NAME=${cluster_name}/" "$env_file" || return 1
    cross_platform_sed_inplace "s/^CLUSTER_NAME=.*/CLUSTER_NAME=${cluster_name}/" "$env_file" || return 1

    # Update GITOPS_BRANCH
    cross_platform_sed_inplace "s/^# *GITOPS_BRANCH=.*/GITOPS_BRANCH=user\/${git_user}\/${worktree_name}/" "$env_file" || return 1
    cross_platform_sed_inplace "s/^GITOPS_BRANCH=.*/GITOPS_BRANCH=user\/${git_user}\/${worktree_name}/" "$env_file" || return 1

    # Enable Flux
    cross_platform_sed_inplace "s/^# *FLUX_ENABLED=.*/FLUX_ENABLED=true/" "$env_file" || return 1
    cross_platform_sed_inplace "s/^FLUX_ENABLED=.*/FLUX_ENABLED=true/" "$env_file" || return 1

    # Add KIND_CONFIG (avoid duplicates)
    local kind_config_line="KIND_CONFIG=extension/${worktree_name}"
    if ! grep -q "^KIND_CONFIG=extension/${worktree_name}$" "$env_file" 2>/dev/null; then
        if ! echo "$kind_config_line" >> "$env_file"; then
            log_error "update_env_file: failed to append KIND_CONFIG to $env_file"
            return 1
        fi
    fi

    log_debug "Environment file updated successfully"
    return 0
}

# Initialize common environment when sourced
load_environment
