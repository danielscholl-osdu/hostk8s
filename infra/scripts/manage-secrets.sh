#!/bin/bash

#######################################
# HostK8s Vault-Enhanced Secret Management Script
# Reads hostk8s.secrets.yaml contracts and:
# 1. Populates Vault with secret values
# 2. Generates external-secrets.yaml for GitOps deployment
#######################################

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/common.sh"

# Command line parsing
COMMAND=""
STACK=""

# Parse arguments - support both old and new formats
if [ $# -eq 1 ]; then
    # Could be either legacy format or list command
    if [[ "$1" == "list" ]]; then
        COMMAND="list"
        STACK=""
    else
        # Legacy format: manage-secrets.sh <stack>
        COMMAND="add"
        STACK="$1"
    fi
elif [ $# -eq 2 ]; then
    # New format: manage-secrets.sh <command> <stack>
    COMMAND="$1"
    STACK="$2"
else
    COMMAND=""
    STACK=""
fi

# Variables
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8080}"
VAULT_TOKEN="${VAULT_TOKEN:-hostk8s}"

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
# Check if secret already exists in Vault
#######################################
vault_secret_exists() {
    local path="$1"

    # Use curl to check if secret exists via Vault API
    local response=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/${path}" 2>/dev/null || echo "")

    if echo "$response" | grep -q '"data"'; then
        return 0  # exists
    else
        return 1  # doesn't exist
    fi
}

#######################################
# Store secret in Vault
#######################################
store_vault_secret() {
    local path="$1"
    local json_data="$2"

    log_debug "Storing secret in Vault: secret/${path}"

    # Create the payload for Vault KV v2
    local payload="{\"data\": ${json_data}}"

    # Store in Vault using curl
    local response=$(curl -s -w "%{http_code}" \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "${payload}" \
        "${VAULT_ADDR}/v1/secret/data/${path}")

    local status_code="${response: -3}"
    if [[ "${status_code}" =~ ^2[0-9][0-9]$ ]]; then
        return 0
    else
        log_error "Failed to store secret ${path}: HTTP ${status_code}"
        return 1
    fi
}

#######################################
# Generate ExternalSecret manifest for a secret
#######################################
generate_external_secret_manifest() {
    local secret_name="$1"
    local namespace="$2"
    local data_json="$3"
    local vault_path="${STACK}/${namespace}/${secret_name}"

    echo "---"
    echo "apiVersion: external-secrets.io/v1"
    echo "kind: ExternalSecret"
    echo "metadata:"
    echo "  name: ${secret_name}"
    echo "  namespace: ${namespace}"
    echo "  labels:"
    echo "    hostk8s.io/managed: \"true\""
    echo "    hostk8s.io/contract: \"${STACK}\""
    echo "spec:"
    echo "  refreshInterval: 10s"
    echo "  secretStoreRef:"
    echo "    name: vault-backend"
    echo "    kind: ClusterSecretStore"
    echo "  target:"
    echo "    name: ${secret_name}"
    echo "    creationPolicy: Owner"
    echo "  data:"

    # Process each data entry to create remoteRef mappings
    local data_count=$(echo "${data_json}" | yq eval '. | length' -)

    for ((j=0; j<${data_count}; j++)); do
        local key=$(echo "${data_json}" | yq eval ".[${j}].key" -)
        echo "  - secretKey: ${key}"
        echo "    remoteRef:"
        echo "      key: ${vault_path}"
        echo "      property: ${key}"
    done
}

#######################################
# Process secret from contract data
#######################################
process_secret_data() {
    local secret_name="$1"
    local namespace="$2"
    local data_json="$3"
    local external_secrets_file="$4"

    # Create Vault path: stack/namespace/secret-name
    local vault_path="${STACK}/${namespace}/${secret_name}"

    # Check if secret already exists in Vault (idempotency)
    if vault_secret_exists "${vault_path}"; then
        log_info "Secret '${secret_name}' already exists in Vault, skipping Vault population"
    else
        log_info "Populating Vault with secret '${secret_name}' for namespace '${namespace}'"

        # Build JSON object for Vault storage
        local vault_data="{"
        local first=true

        # Process each data entry
        local data_count=$(echo "${data_json}" | yq eval '. | length' -)

        for ((j=0; j<${data_count}; j++)); do
            local key=$(echo "${data_json}" | yq eval ".[${j}].key" -)
            local value=$(echo "${data_json}" | yq eval ".[${j}].value // null" -)
            local generate_type=$(echo "${data_json}" | yq eval ".[${j}].generate // null" -)
            local length=$(echo "${data_json}" | yq eval ".[${j}].length // 32" -)

            if [[ "${first}" == "false" ]]; then
                vault_data+=","
            fi
            first=false

            if [[ "${value}" != "null" ]]; then
                # Static value
                vault_data+="\"${key}\": \"${value}\""
            elif [[ "${generate_type}" != "null" ]]; then
                # Generated value
                local generated_value=""
                case "${generate_type}" in
                    password)
                        generated_value=$(generate_password ${length})
                        ;;
                    token)
                        generated_value=$(generate_token ${length})
                        ;;
                    hex)
                        generated_value=$(generate_hex ${length})
                        ;;
                    uuid)
                        if command -v uuidgen &> /dev/null; then
                            generated_value=$(uuidgen | tr '[:upper:]' '[:lower:]')
                        else
                            # Fallback to random hex
                            generated_value=$(generate_hex 32)
                        fi
                        ;;
                    *)
                        generated_value=$(generate_token ${length})
                        ;;
                esac
                vault_data+="\"${key}\": \"${generated_value}\""
            fi
        done

        vault_data+="}"

        # Store in Vault
        store_vault_secret "${vault_path}" "${vault_data}" || {
            log_error "Failed to store secret in Vault"
            return 1
        }
    fi

    # Always generate ExternalSecret manifest (even if Vault secret exists)
    log_debug "Generating ExternalSecret manifest for '${secret_name}'"
    generate_external_secret_manifest "${secret_name}" "${namespace}" "${data_json}" >> "${external_secrets_file}"
}

#######################################
# Show usage information
#######################################
show_usage() {
    echo "Usage: $0 [COMMAND] <stack-name>"
    echo ""
    echo "Commands:"
    echo "  add <stack>     Add/update secrets in Vault and generate manifests (default)"
    echo "  remove <stack>  Remove all secrets for stack from Vault"
    echo "  list [stack]    List secrets in Vault (all stacks or specific stack)"
    echo ""
    echo "Legacy format (defaults to 'add'):"
    echo "  $0 <stack>      Same as: $0 add <stack>"
    echo ""
    echo "Examples:"
    echo "  $0 add sample-app       # Populate Vault + generate manifests"
    echo "  $0 remove sample-app    # Clean up Vault secrets"
    echo "  $0 list                 # List all secrets"
    echo "  $0 list sample-app      # List secrets for specific stack"
    echo "  $0 sample-app           # Legacy format (same as add)"
}

#######################################
# List secrets in Vault
#######################################
list_secrets() {
    local filter_stack="${1:-}"

    log_info "Listing secrets in Vault..."

    # Check Vault connectivity
    if ! check_vault_connectivity; then
        exit 1
    fi

    if [[ -n "${filter_stack}" ]]; then
        log_info "Filtering for stack: ${filter_stack}"
        # List secrets for specific stack: secret/metadata/stack/*
        vault_path="secret/metadata/${filter_stack}"
    else
        # List all secrets: secret/metadata/*
        vault_path="secret/metadata"
    fi

    log_debug "Querying Vault path: ${vault_path}"

    # Use Vault API to list secrets
    vault_response=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/${vault_path}?list=true" || echo "")

    if [[ -z "${vault_response}" ]] || echo "${vault_response}" | grep -q "errors"; then
        if [[ -n "${filter_stack}" ]]; then
            log_info "No secrets found for stack '${filter_stack}'"
        else
            log_info "No secrets found in Vault"
        fi
        return 0
    fi

    # Parse and display results
    if command -v jq &> /dev/null; then
        echo "${vault_response}" | jq -r '.data.keys[]?' 2>/dev/null | while read -r key; do
            if [[ -n "${key}" ]]; then
                if [[ -n "${filter_stack}" ]]; then
                    log_success "  ${filter_stack}/${key}"
                else
                    log_success "  ${key}"
                fi
            fi
        done
    else
        log_warn "Install 'jq' for better secret listing output"
        echo "${vault_response}"
    fi
}

#######################################
# Remove secrets for a stack from Vault
#######################################
remove_secrets() {
    if [[ -z "${STACK}" ]]; then
        log_error "Stack name required. Usage: $0 remove <stack-name>"
        exit 1
    fi

    log_info "Removing secrets for stack '${STACK}' from Vault..."

    # Check Vault connectivity
    if ! check_vault_connectivity; then
        exit 1
    fi

    local CONTRACT_FILE="software/stacks/${STACK}/hostk8s.secrets.yaml"
    local EXTERNAL_SECRETS_FILE="software/stacks/${STACK}/manifests/external-secrets.yaml"

    if [[ ! -f "${CONTRACT_FILE}" ]]; then
        log_warn "No secret contract found for stack '${STACK}'"
        log_info "Attempting to remove any existing secrets anyway..."

        # Try to remove by pattern: secret/metadata/STACK/*
        vault_path="secret/metadata/${STACK}"
        vault_response=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
            "${VAULT_ADDR}/v1/${vault_path}?list=true" || echo "")

        if [[ -n "${vault_response}" ]] && ! echo "${vault_response}" | grep -q "errors"; then
            if command -v jq &> /dev/null; then
                echo "${vault_response}" | jq -r '.data.keys[]?' 2>/dev/null | while read -r namespace; do
                    if [[ -n "${namespace}" ]]; then
                        remove_secrets_in_path "${STACK}/${namespace}"
                    fi
                done
            fi
        else
            log_info "No secrets found for stack '${STACK}'"
        fi

        # Remove external-secrets.yaml if it exists
        if [[ -f "${EXTERNAL_SECRETS_FILE}" ]]; then
            log_info "Removing ExternalSecret manifests: ${EXTERNAL_SECRETS_FILE}"
            rm -f "${EXTERNAL_SECRETS_FILE}"
        fi

        log_success "Secret removal completed for stack '${STACK}'"
        return 0
    fi

    log_info "Reading secret contract: ${CONTRACT_FILE}"

    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for parsing YAML contracts"
        log_error "Install from: https://github.com/mikefarah/yq"
        exit 1
    fi

    # Process each secret in the contract for removal
    local secret_count
    secret_count=$(yq eval '.spec.secrets | length' "${CONTRACT_FILE}")

    for (( i=0; i<secret_count; i++ )); do
        local name namespace vault_path
        name=$(yq eval ".spec.secrets[${i}].name" "${CONTRACT_FILE}")
        namespace=$(yq eval ".spec.secrets[${i}].namespace" "${CONTRACT_FILE}")
        vault_path="${STACK}/${namespace}/${name}"

        log_info "Removing secret '${name}' from Vault path: secret/${vault_path}"

        # Delete from Vault
        if ! remove_vault_secret "${vault_path}"; then
            log_warn "Failed to remove secret: ${vault_path}"
        fi
    done

    # Remove external-secrets.yaml file
    if [[ -f "${EXTERNAL_SECRETS_FILE}" ]]; then
        log_info "Removing ExternalSecret manifests: ${EXTERNAL_SECRETS_FILE}"
        rm -f "${EXTERNAL_SECRETS_FILE}"
    fi

    log_success "Secret removal completed for stack '${STACK}'"
}

#######################################
# Remove secrets from a Vault path pattern
#######################################
remove_secrets_in_path() {
    local base_path="$1"

    # List secrets in the path
    vault_response=$(curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/metadata/${base_path}?list=true" || echo "")

    if [[ -n "${vault_response}" ]] && ! echo "${vault_response}" | grep -q "errors"; then
        if command -v jq &> /dev/null; then
            echo "${vault_response}" | jq -r '.data.keys[]?' 2>/dev/null | while read -r secret_name; do
                if [[ -n "${secret_name}" ]]; then
                    remove_vault_secret "${base_path}/${secret_name}"
                fi
            done
        fi
    fi
}

#######################################
# Remove a single secret from Vault
#######################################
remove_vault_secret() {
    local vault_path="$1"

    log_debug "Removing Vault secret: secret/${vault_path}"

    # Delete secret data
    local delete_response
    delete_response=$(curl -s -X DELETE -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/data/${vault_path}" 2>/dev/null || echo "")

    # Delete secret metadata
    curl -s -X DELETE -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/secret/metadata/${vault_path}" >/dev/null 2>&1 || true

    return 0
}

#######################################
# Check Vault connectivity
#######################################
check_vault_connectivity() {
    if ! curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" \
         "${VAULT_ADDR}/v1/sys/health" >/dev/null 2>&1; then
        log_error "Cannot connect to Vault at ${VAULT_ADDR}"
        log_error "Make sure Vault is running and VAULT_ADDR/VAULT_TOKEN are set correctly"
        return 1
    fi
    return 0
}

#######################################
# Add secrets from contract (enhanced for Vault)
#######################################
add_secrets() {
    if [[ -z "${STACK}" ]]; then
        log_error "Stack name required. Usage: $0 add <stack-name>"
        exit 1
    fi

    # Check Vault connectivity
    if ! check_vault_connectivity; then
        exit 1
    fi

    CONTRACT_FILE="software/stacks/${STACK}/hostk8s.secrets.yaml"
    EXTERNAL_SECRETS_FILE="software/stacks/${STACK}/manifests/external-secrets.yaml"

    if [[ ! -f "${CONTRACT_FILE}" ]]; then
        log_info "No secret contract found for stack '${STACK}'"
        return 0
    fi

    log_info "Processing secrets for stack '${STACK}' (Vault + ExternalSecrets)"

    # Parse contract using yq
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for parsing YAML contracts"
        log_error "Install with: brew install yq (Mac) or download from https://github.com/mikefarah/yq"
        exit 1
    fi

    # Check Vault connectivity
    if ! curl -s -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/sys/health" > /dev/null; then
        log_error "Cannot connect to Vault at ${VAULT_ADDR}"
        log_error "Make sure Vault is running and VAULT_ADDR/VAULT_TOKEN are set correctly"
        exit 1
    fi

    # Ensure manifests directory exists
    mkdir -p "software/stacks/${STACK}/manifests"

    # Create external-secrets.yaml file with header
    cat > "${EXTERNAL_SECRETS_FILE}" <<EOF
# Generated ExternalSecret manifests from hostk8s.secrets.yaml
# This file is auto-generated by manage-secrets.sh - safe to commit to Git
# Contains no sensitive data - only Vault path references
# To regenerate: make up ${STACK}
EOF

    # Process each secret in the contract
    local secret_count=$(yq eval '.spec.secrets | length' "${CONTRACT_FILE}")

    for ((i=0; i<${secret_count}; i++)); do
        local name=$(yq eval ".spec.secrets[${i}].name" "${CONTRACT_FILE}")
        local namespace=$(yq eval ".spec.secrets[${i}].namespace" "${CONTRACT_FILE}")

        # Use generic data format
        local data_json=$(yq eval ".spec.secrets[${i}].data" "${CONTRACT_FILE}" -o=json)
        process_secret_data "${name}" "${namespace}" "${data_json}" "${EXTERNAL_SECRETS_FILE}"
    done

    log_success "Secrets processed successfully for stack '${STACK}'"
    log_info "✅ Vault populated with secret values"
    log_info "✅ ExternalSecret manifests generated: ${EXTERNAL_SECRETS_FILE}"
    log_info "✅ Ready for GitOps deployment via Flux"
}

#######################################
# Main execution
#######################################

# Validate command and execute
case "${COMMAND}" in
    "add")
        add_secrets
        ;;
    "remove")
        remove_secrets
        ;;
    "list")
        list_secrets "${STACK}"
        ;;
    "")
        show_usage
        exit 1
        ;;
    *)
        log_error "Unknown command: ${COMMAND}"
        echo ""
        show_usage
        exit 1
        ;;
esac
