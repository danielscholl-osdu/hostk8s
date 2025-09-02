#!/bin/bash

#######################################
# HostK8s Secret Management Script
# Handles ephemeral secret generation from contracts
#######################################

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Variables
ACTION="${1:-help}"
STACK="${2:-}"
CONTRACT_FILE=""
SECRETS_DIR=""
NAMESPACE=""

#######################################
# Show help message
#######################################
show_help() {
    cat << EOF
HostK8s Secret Management

Usage: make secrets <action> [STACK=stack-name]

Actions:
  generate    Generate secrets from contract for a stack
  show        Display current secrets for a stack
  clean       Remove secrets for a stack from cluster
  help        Show this help message

Examples:
  make secrets generate STACK=sample-app
  make secrets show STACK=sample-app
  make secrets clean STACK=sample-app

EOF
}

#######################################
# Generate random password
#######################################
generate_password() {
    local length="${1:-32}"
    if command -v openssl &> /dev/null; then
        openssl rand -base64 48 | tr -d "=+/" | cut -c1-"${length}"
    else
        # Fallback to /dev/urandom
        LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "${length}"
    fi
}

#######################################
# Generate alphanumeric token
#######################################
generate_token() {
    local length="${1:-32}"
    if command -v openssl &> /dev/null; then
        openssl rand -base64 48 | tr -d "=+/\n" | tr '+' 'x' | tr '/' 'y' | cut -c1-"${length}"
    else
        LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${length}"
    fi
}

#######################################
# Generate hex string
#######################################
generate_hex() {
    local length="${1:-32}"
    if command -v openssl &> /dev/null; then
        openssl rand -hex $((length / 2))
    else
        LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c "${length}"
    fi
}

#######################################
# Check if secret exists in cluster
#######################################
secret_exists() {
    local name="$1"
    local namespace="$2"

    if kubectl get secret "${name}" -n "${namespace}" &>/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

#######################################
# Generate PostgreSQL secret
#######################################
generate_postgresql_secret() {
    local secret_name="$1"
    local namespace="$2"
    local username="${3:-postgres}"
    local database="${4:-postgres}"
    local cluster="${5:-postgres}"

    local password=$(generate_password 32)
    local host="${cluster}-rw.${namespace}.svc.cluster.local"
    local port="5432"
    local url="postgresql://${username}:${password}@${host}:${port}/${database}"

    cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
  labels:
    hostk8s.io/managed: "true"
    hostk8s.io/contract: "${STACK}"
    hostk8s.io/type: "postgresql"
type: kubernetes.io/basic-auth
stringData:
  username: "${username}"
  password: "${password}"
  database: "${database}"
  host: "${host}"
  port: "${port}"
  url: "${url}"
EOF
}

#######################################
# Generate Redis secret
#######################################
generate_redis_secret() {
    local secret_name="$1"
    local namespace="$2"
    local service="${3:-redis}"

    local password=$(generate_password 32)
    local host="${service}.${namespace}.svc.cluster.local"
    local port="6379"

    cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
  labels:
    hostk8s.io/managed: "true"
    hostk8s.io/contract: "${STACK}"
    hostk8s.io/type: "redis"
type: Opaque
stringData:
  password: "${password}"
  host: "${host}"
  port: "${port}"
EOF
}

#######################################
# Generate generic secret
#######################################
generate_generic_secret() {
    local secret_name="$1"
    local namespace="$2"
    shift 2

    echo "---"
    echo "apiVersion: v1"
    echo "kind: Secret"
    echo "metadata:"
    echo "  name: ${secret_name}"
    echo "  namespace: ${namespace}"
    echo "  labels:"
    echo "    hostk8s.io/managed: \"true\""
    echo "    hostk8s.io/contract: \"${STACK}\""
    echo "    hostk8s.io/type: \"generic\""
    echo "type: Opaque"
    echo "stringData:"

    # Process field definitions passed as arguments
    while [[ $# -gt 0 ]]; do
        local field_name="$1"
        local field_type="$2"
        local field_value="$3"
        shift 3 || break

        case "${field_type}" in
            password)
                echo "  ${field_name}: \"$(generate_password ${field_value})\""
                ;;
            token)
                echo "  ${field_name}: \"$(generate_token ${field_value})\""
                ;;
            hex)
                echo "  ${field_name}: \"$(generate_hex ${field_value})\""
                ;;
            static)
                echo "  ${field_name}: \"${field_value}\""
                ;;
            *)
                echo "  ${field_name}: \"$(generate_token ${field_value})\""
                ;;
        esac
    done
}

#######################################
# Generate API key secret
#######################################
generate_apikey_secret() {
    local secret_name="$1"
    local namespace="$2"
    local prefix="${3:-}"
    local length="${4:-32}"

    local key="${prefix}$(generate_token ${length})"

    cat << EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
  labels:
    hostk8s.io/managed: "true"
    hostk8s.io/contract: "${STACK}"
    hostk8s.io/type: "apikey"
type: Opaque
stringData:
  key: "${key}"
EOF
}

#######################################
# Parse and generate secrets from contract
#######################################
generate_secrets() {
    if [[ -z "${STACK}" ]]; then
        error "Stack name required. Use: make secrets generate STACK=<name>"
        exit 1
    fi

    CONTRACT_FILE="software/stacks/${STACK}/secrets.contract.yaml"
    SECRETS_DIR="data/secrets/${STACK}"

    if [[ ! -f "${CONTRACT_FILE}" ]]; then
        info "No secret contract found for stack '${STACK}'"
        return 0
    fi

    info "Generating secrets for stack '${STACK}'"

    # Create secrets directory
    mkdir -p "${SECRETS_DIR}"

    # Temporary file for generated secrets
    local temp_file="${SECRETS_DIR}/generated.tmp.yaml"
    > "${temp_file}"

    # Parse contract using yq
    if ! command -v yq &> /dev/null; then
        error "yq is required for parsing YAML contracts"
        error "Install with: brew install yq (Mac) or download from https://github.com/mikefarah/yq"
        exit 1
    fi

    # Process each secret in the contract
    local secret_count=$(yq eval '.spec.secrets | length' "${CONTRACT_FILE}")

    for ((i=0; i<${secret_count}; i++)); do
        local name=$(yq eval ".spec.secrets[${i}].name" "${CONTRACT_FILE}")
        local namespace=$(yq eval ".spec.secrets[${i}].namespace" "${CONTRACT_FILE}")
        local type=$(yq eval ".spec.secrets[${i}].type" "${CONTRACT_FILE}")

        # Skip if secret already exists (idempotency)
        if secret_exists "${name}" "${namespace}"; then
            info "Secret '${name}' already exists in namespace '${namespace}', skipping"
            continue
        fi

        info "Generating secret '${name}' of type '${type}'"

        case "${type}" in
            postgresql)
                local username=$(yq eval ".spec.secrets[${i}].spec.username // \"postgres\"" "${CONTRACT_FILE}")
                local database=$(yq eval ".spec.secrets[${i}].spec.database" "${CONTRACT_FILE}")
                local cluster=$(yq eval ".spec.secrets[${i}].spec.cluster" "${CONTRACT_FILE}")
                generate_postgresql_secret "${name}" "${namespace}" "${username}" "${database}" "${cluster}" >> "${temp_file}"
                ;;

            redis)
                local service=$(yq eval ".spec.secrets[${i}].spec.service // \"redis\"" "${CONTRACT_FILE}")
                generate_redis_secret "${name}" "${namespace}" "${service}" >> "${temp_file}"
                ;;

            apikey)
                local prefix=$(yq eval ".spec.secrets[${i}].spec.prefix // \"\"" "${CONTRACT_FILE}")
                local length=$(yq eval ".spec.secrets[${i}].spec.length // 32" "${CONTRACT_FILE}")
                generate_apikey_secret "${name}" "${namespace}" "${prefix}" "${length}" >> "${temp_file}"
                ;;

            generic)
                # Build field arguments for generic secret
                local field_args=""
                local field_count=$(yq eval ".spec.secrets[${i}].spec.fields | length" "${CONTRACT_FILE}")

                for ((j=0; j<${field_count}; j++)); do
                    local field_name=$(yq eval ".spec.secrets[${i}].spec.fields[${j}].name" "${CONTRACT_FILE}")
                    local field_generate=$(yq eval ".spec.secrets[${i}].spec.fields[${j}].generate // \"token\"" "${CONTRACT_FILE}")
                    local field_value=$(yq eval ".spec.secrets[${i}].spec.fields[${j}].length // .spec.secrets[${i}].spec.fields[${j}].value // 32" "${CONTRACT_FILE}")
                    field_args="${field_args} ${field_name} ${field_generate} ${field_value}"
                done

                generate_generic_secret "${name}" "${namespace}" ${field_args} >> "${temp_file}"
                ;;

            *)
                warn "Unknown secret type '${type}' for secret '${name}', skipping"
                ;;
        esac
    done

    # Apply generated secrets to cluster
    if [[ -s "${temp_file}" ]]; then
        info "Applying generated secrets to cluster"
        kubectl apply -f "${temp_file}"

        # Save a copy for reference (but it's gitignored)
        cp "${temp_file}" "${SECRETS_DIR}/generated.yaml"
        rm "${temp_file}"

        success "Secrets generated and applied successfully"
    else
        info "No new secrets to generate"
    fi
}

#######################################
# Show secrets for a stack
#######################################
show_secrets() {
    if [[ -z "${STACK}" ]]; then
        error "Stack name required. Use: make secrets show STACK=<name>"
        exit 1
    fi

    info "Showing secrets for stack '${STACK}'"

    # Get the namespace from the contract
    CONTRACT_FILE="software/stacks/${STACK}/secrets.contract.yaml"
    if [[ ! -f "${CONTRACT_FILE}" ]]; then
        error "No secret contract found for stack '${STACK}'"
        exit 1
    fi

    # Get unique namespaces from contract
    local namespaces=$(yq eval '.spec.secrets[].namespace' "${CONTRACT_FILE}" | sort -u)

    for namespace in ${namespaces}; do
        echo ""
        info "Secrets in namespace '${namespace}':"
        kubectl get secrets -n "${namespace}" -l "hostk8s.io/contract=${STACK}" \
            -o custom-columns=NAME:.metadata.name,TYPE:.metadata.labels.hostk8s\\.io/type,AGE:.metadata.creationTimestamp
    done
}

#######################################
# Clean secrets for a stack
#######################################
clean_secrets() {
    if [[ -z "${STACK}" ]]; then
        error "Stack name required. Use: make secrets clean STACK=<name>"
        exit 1
    fi

    warn "Removing secrets for stack '${STACK}'"

    # Get the namespace from the contract
    CONTRACT_FILE="software/stacks/${STACK}/secrets.contract.yaml"
    if [[ ! -f "${CONTRACT_FILE}" ]]; then
        error "No secret contract found for stack '${STACK}'"
        exit 1
    fi

    # Get unique namespaces from contract
    local namespaces=$(yq eval '.spec.secrets[].namespace' "${CONTRACT_FILE}" | sort -u)

    for namespace in ${namespaces}; do
        info "Cleaning secrets in namespace '${namespace}'"
        kubectl delete secrets -n "${namespace}" -l "hostk8s.io/contract=${STACK}" --ignore-not-found=true
    done

    # Clean local cache
    SECRETS_DIR="data/secrets/${STACK}"
    if [[ -d "${SECRETS_DIR}" ]]; then
        rm -rf "${SECRETS_DIR}"
        info "Cleaned local secret cache"
    fi

    success "Secrets cleaned successfully"
}

#######################################
# Main execution
#######################################
case "${ACTION}" in
    generate)
        generate_secrets
        ;;
    show)
        show_secrets
        ;;
    clean)
        clean_secrets
        ;;
    help|*)
        show_help
        ;;
esac
