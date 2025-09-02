#!/bin/bash

#######################################
# HostK8s Secret Generation Script
# Generates ephemeral secrets from hostk8s.secrets.yaml contract files
#######################################

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Variables
STACK="${1:-}"

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
# Wait for namespace to be ready
#######################################
wait_for_namespace() {
    local namespace="$1"
    local timeout="${2:-60}"  # Default 60 second timeout
    local count=0

    log_info "Waiting for namespace '${namespace}' to be ready..."

    while ! kubectl get namespace "${namespace}" &>/dev/null; do
        if [ $count -ge $timeout ]; then
            log_error "Timeout waiting for namespace '${namespace}' to be created"
            log_error "Run 'kubectl get namespace ${namespace}' to check status"
            return 1
        fi

        sleep 2
        count=$((count + 2))
        echo -n "."
    done

    echo ""
    log_success "Namespace '${namespace}' is ready"
    return 0
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
# Generate secret from generic data format
#######################################
generate_secret_from_data() {
    local secret_name="$1"
    local namespace="$2"
    local data_json="$3"

    echo "---"
    echo "apiVersion: v1"
    echo "kind: Secret"
    echo "metadata:"
    echo "  name: ${secret_name}"
    echo "  namespace: ${namespace}"
    echo "  labels:"
    echo "    hostk8s.io/managed: \"true\""
    echo "    hostk8s.io/contract: \"${STACK}\""
    echo "type: Opaque"
    echo "stringData:"

    # Process each data entry
    local data_count=$(echo "${data_json}" | yq eval '. | length' -)

    for ((j=0; j<${data_count}; j++)); do
        local key=$(echo "${data_json}" | yq eval ".[${j}].key" -)
        local value=$(echo "${data_json}" | yq eval ".[${j}].value // null" -)
        local generate_type=$(echo "${data_json}" | yq eval ".[${j}].generate // null" -)
        local length=$(echo "${data_json}" | yq eval ".[${j}].length // 32" -)

        if [[ "${value}" != "null" ]]; then
            # Static value
            echo "  ${key}: \"${value}\""
        elif [[ "${generate_type}" != "null" ]]; then
            # Generated value
            case "${generate_type}" in
                password)
                    echo "  ${key}: \"$(generate_password ${length})\""
                    ;;
                token)
                    echo "  ${key}: \"$(generate_token ${length})\""
                    ;;
                hex)
                    echo "  ${key}: \"$(generate_hex ${length})\""
                    ;;
                uuid)
                    if command -v uuidgen &> /dev/null; then
                        echo "  ${key}: \"$(uuidgen | tr '[:upper:]' '[:lower:]')\""
                    else
                        # Fallback to random hex
                        echo "  ${key}: \"$(generate_hex 32)\""
                    fi
                    ;;
                *)
                    echo "  ${key}: \"$(generate_token ${length})\""
                    ;;
            esac
        fi
    done
}

#######################################
# Generate secrets from contract
#######################################
generate_secrets() {
    if [[ -z "${STACK}" ]]; then
        log_error "Stack name required. Usage: manage-secrets.sh <stack-name>"
        exit 1
    fi

    CONTRACT_FILE="software/stacks/${STACK}/hostk8s.secrets.yaml"
    SECRETS_DIR="data/secrets/${STACK}"

    if [[ ! -f "${CONTRACT_FILE}" ]]; then
        log_info "No secret contract found for stack '${STACK}'"
        return 0
    fi

    log_info "Generating secrets for stack '${STACK}'"

    # Create secrets directory
    mkdir -p "${SECRETS_DIR}"

    # Temporary file for generated secrets
    local temp_file="${SECRETS_DIR}/generated.tmp.yaml"
    > "${temp_file}"

    # Parse contract using yq
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for parsing YAML contracts"
        log_error "Install with: brew install yq (Mac) or download from https://github.com/mikefarah/yq"
        exit 1
    fi

    # Get unique namespaces first and wait for them to be ready
    local namespaces=$(yq eval '.spec.secrets[].namespace' "${CONTRACT_FILE}" | sort -u)
    for namespace in ${namespaces}; do
        wait_for_namespace "${namespace}" || exit 1
    done

    # Process each secret in the contract
    local secret_count=$(yq eval '.spec.secrets | length' "${CONTRACT_FILE}")

    for ((i=0; i<${secret_count}; i++)); do
        local name=$(yq eval ".spec.secrets[${i}].name" "${CONTRACT_FILE}")
        local namespace=$(yq eval ".spec.secrets[${i}].namespace" "${CONTRACT_FILE}")

        # Skip if secret already exists (idempotency)
        if secret_exists "${name}" "${namespace}"; then
            log_info "Secret '${name}' already exists in namespace '${namespace}', skipping"
            continue
        fi

        log_info "Generating secret '${name}'"

        # Use new generic data format
        local data_json=$(yq eval ".spec.secrets[${i}].data" "${CONTRACT_FILE}" -o=json)
        generate_secret_from_data "${name}" "${namespace}" "${data_json}" >> "${temp_file}"
    done

    # Apply generated secrets to cluster
    if [[ -s "${temp_file}" ]]; then
        log_info "Applying generated secrets to cluster"
        kubectl apply -f "${temp_file}"

        # Save a copy for reference (but it's gitignored)
        cp "${temp_file}" "${SECRETS_DIR}/generated.yaml"
        rm "${temp_file}"

        log_success "Secrets generated and applied successfully"
    else
        log_info "No new secrets to generate"
    fi
}

#######################################
# Main execution
#######################################
generate_secrets
