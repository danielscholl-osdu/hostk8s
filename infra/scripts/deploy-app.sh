#!/bin/bash
# infra/scripts/deploy-app.sh - Deploy application to cluster
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [remove] [APP_NAME]"
    echo ""
    echo "Deploy or remove an application to/from the cluster."
    echo ""
    echo "Arguments:"
    echo "  remove      Remove mode - removes the application"
    echo "  APP_NAME    Application to deploy/remove (default: simple)"
    echo ""
    echo "Available applications:"
    list_available_apps | sed 's/^/  /'
    echo ""
    echo "Examples:"
    echo "  $0                     # Deploy default app (simple)"
    echo "  $0 simple             # Deploy basic sample app"
    echo "  $0 remove simple      # Remove basic sample app"
    echo "  $0 remove voting-app  # Remove custom app"
}

deploy_helm_app() {
    local app_name="$1"
    local app_dir="$2"
    local namespace="$3"

    # Default values file
    local values_file="$app_dir/values.yaml"

    # Environment-specific values (development by default for HostK8s)
    local env_values="$app_dir/values/development.yaml"

    # Helm command arguments
    local helm_args=(
        --namespace "$namespace"
        --create-namespace
        --set "global.labels.hostk8s\.app=$app_name"
    )

    # Add environment-specific values if they exist
    if [ -f "$env_values" ]; then
        helm_args+=(-f "$env_values")
        log_info "Using development values: $env_values"
    fi

    # Check if Helm is available
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Please install Helm to deploy chart-based apps."
        log_info "Run: make install (includes Helm installation)"
        exit 1
    fi

    # Deploy using Helm
    log_info "Deploying Helm chart: $app_dir to namespace: $namespace"
    if helm upgrade --install "$app_name" "$app_dir" "${helm_args[@]}"; then
        log_success "$app_name deployed successfully via Helm to $namespace"
        log_info "See software/apps/$app_name/README.md for access details"
        log_info "Use 'helm status $app_name -n $namespace' for deployment status"
    else
        log_error "Failed to deploy $app_name via Helm to $namespace"
        log_info "Check chart syntax with: helm lint $app_dir"
        exit 1
    fi
}

remove_helm_app() {
    local app_name="$1"
    local namespace="$2"

    # Check if Helm is available
    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed. Cannot remove Helm releases."
        log_info "Run: make install (includes Helm installation)"
        exit 1
    fi

    # Check if release exists in the specified namespace
    if helm list -q -n "$namespace" | grep -q "^$app_name$"; then
        log_info "Uninstalling Helm release: $app_name from namespace: $namespace"
        if helm uninstall "$app_name" -n "$namespace"; then
            log_success "$app_name removed successfully via Helm from $namespace"
        else
            log_error "Failed to remove $app_name via Helm from $namespace"
            exit 1
        fi
    else
        log_info "Helm release $app_name not found in $namespace, trying label-based removal..."
        if kubectl delete all,ingress,configmap,secret -l "hostk8s.app=$app_name" -n "$namespace" 2>/dev/null; then
            log_success "$app_name removed successfully (label-based) from $namespace"
        else
            log_warn "No resources found for app: $app_name in namespace: $namespace (may already be removed)"
        fi
    fi
}

# Namespace management functions
ensure_namespace() {
    local namespace="$1"

    if [ "$namespace" = "default" ]; then
        return 0  # Default namespace always exists
    fi

    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_debug "Namespace $namespace already exists"
        return 0
    fi

    log_info "Creating namespace: $namespace"
    if kubectl create namespace "$namespace"; then
        # Label the namespace so we know we created it
        kubectl label namespace "$namespace" "hostk8s.created=true" >/dev/null 2>&1
        log_success "Namespace $namespace created"
    else
        log_error "Failed to create namespace: $namespace"
        exit 1
    fi
}

cleanup_namespace_if_empty() {
    local namespace="$1"

    # Never remove default or system namespaces
    case "$namespace" in
        "default"|"kube-system"|"kube-public"|"kube-node-lease"|"flux-system"|"metallb-system"|"ingress-nginx")
            return 0
            ;;
    esac

    # Only remove namespaces we created
    local created_by_us=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.hostk8s\.created}' 2>/dev/null || echo "")
    if [ "$created_by_us" != "true" ]; then
        log_debug "Not removing namespace $namespace (not created by HostK8s)"
        return 0
    fi

    # Check if namespace has any hostk8s-managed resources
    local resource_count=$(kubectl get all,ingress,configmap,secret -l hostk8s.app -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [ "$resource_count" -eq "0" ]; then
        log_info "Removing empty namespace: $namespace"
        if kubectl delete namespace "$namespace"; then
            log_success "Namespace $namespace removed"
        else
            log_warn "Failed to remove namespace: $namespace"
        fi
    else
        log_debug "Not removing namespace $namespace (contains $resource_count resources)"
    fi
}

deploy_application() {
    local app_name="$1"
    local namespace="$2"

    log_deploy "Deploying application..."
    log_info "Deploying app: $app_name to namespace: $namespace"

    # Validate app exists
    if ! validate_app_exists "$app_name"; then
        exit 1
    fi

    # Ensure namespace exists (create if necessary)
    ensure_namespace "$namespace"

    # Determine deployment type and deploy accordingly
    local deployment_type=$(get_app_deployment_type "$app_name")
    local app_dir="software/apps/$app_name"

    case "$deployment_type" in
        "helm")
            log_info "Using Helm chart deployment"
            deploy_helm_app "$app_name" "$app_dir" "$namespace"
            ;;
        "kustomization")
            log_info "Using Kustomization deployment (preferred)"
            if kubectl apply -k "$app_dir" -n "$namespace"; then
                log_success "$app_name deployed successfully via Kustomization to $namespace"
                log_info "See software/apps/$app_name/README.md for access details"
            else
                log_error "Failed to deploy $app_name via Kustomization to $namespace"
                exit 1
            fi
            ;;
        "legacy")
            log_info "Using legacy app.yaml deployment"
            local app_file="$app_dir/app.yaml"
            if kubectl apply -f "$app_file" -n "$namespace"; then
                log_success "$app_name deployed successfully via app.yaml to $namespace"
                log_info "See software/apps/$app_name/README.md for access details"
            else
                log_error "Failed to deploy $app_name via app.yaml to $namespace"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown deployment type for $app_name"
            exit 1
            ;;
    esac
}

remove_application() {
    local app_name="$1"
    local namespace="$2"

    log_deploy "Removing application..."
    log_info "Removing app: $app_name from namespace: $namespace"

    # Validate app exists
    if ! validate_app_exists "$app_name"; then
        exit 1
    fi

    # Determine deployment type and remove accordingly
    local deployment_type=$(get_app_deployment_type "$app_name")
    local app_dir="software/apps/$app_name"

    case "$deployment_type" in
        "helm")
            log_info "Removing Helm release"
            remove_helm_app "$app_name" "$namespace"
            ;;
        "kustomization")
            log_info "Removing Kustomization deployment"
            if kubectl delete -k "$app_dir" -n "$namespace" 2>/dev/null; then
                log_success "$app_name removed successfully via Kustomization from $namespace"
            else
                # Fallback to label-based removal in the specific namespace
                log_info "Trying label-based removal..."
                if kubectl delete all,ingress,configmap,secret -l "hostk8s.app=$app_name" -n "$namespace" 2>/dev/null; then
                    log_success "$app_name removed successfully (label-based) from $namespace"
                else
                    log_warn "No resources found for app: $app_name in namespace: $namespace (may already be removed)"
                fi
            fi
            ;;
        "legacy")
            log_info "Removing legacy app.yaml deployment"
            local app_file="$app_dir/app.yaml"
            if kubectl delete -f "$app_file" -n "$namespace" 2>/dev/null; then
                log_success "$app_name removed successfully via app.yaml from $namespace"
            else
                # Fallback to label-based removal in the specific namespace
                log_info "Trying label-based removal..."
                if kubectl delete all,ingress,configmap,secret -l "hostk8s.app=$app_name" -n "$namespace" 2>/dev/null; then
                    log_success "$app_name removed successfully (label-based) from $namespace"
                else
                    log_warn "No resources found for app: $app_name in namespace: $namespace (may already be removed)"
                fi
            fi
            ;;
        *)
            log_error "Unknown deployment type for $app_name"
            exit 1
            ;;
    esac

    # Clean up namespace if it's empty and we created it
    cleanup_namespace_if_empty "$namespace"
}

# Main function
main() {
    local operation="${1:-}"
    local app_name="${2:-}"
    local namespace="${3:-default}"

    # Show help if requested (check before argument processing)
    if [ "$operation" = "-h" ] || [ "$operation" = "--help" ] || [ "$operation" = "help" ]; then
        show_usage
        exit 0
    fi

    # Handle different argument patterns
    if [ "$operation" = "remove" ]; then
        # Remove mode: remove [app_name] [namespace]
        app_name="${app_name:-simple}"
        namespace="${3:-default}"
    else
        # Deploy mode: [app_name] [namespace]
        app_name="${operation:-simple}"
        namespace="${2:-default}"
        operation="deploy"
    fi

    # Ensure cluster exists and is running (skip for help)
    check_cluster_running

    # Execute the requested operation
    if [ "$operation" = "remove" ]; then
        remove_application "$app_name" "$namespace"
    else
        deploy_application "$app_name" "$namespace"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
