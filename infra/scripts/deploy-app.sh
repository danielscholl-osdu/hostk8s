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
    echo "  $0 remove extension/voting-app  # Remove custom app"
}

deploy_application() {
    local app_name="$1"

    log_deploy "Deploying application..."
    log_info "Deploying app: $app_name"

    # Validate app exists
    if ! validate_app_exists "$app_name"; then
        exit 1
    fi

    # Deploy the application
    local app_file="software/apps/$app_name/app.yaml"
    if kubectl apply -f "$app_file"; then
        log_success "$app_name deployed successfully"
        log_info "See software/apps/$app_name/README.md for access details"
    else
        log_error "Failed to deploy $app_name"
        exit 1
    fi
}

remove_application() {
    local app_name="$1"

    log_deploy "Removing application..."
    log_info "Removing app: $app_name"

    # Validate app exists
    if ! validate_app_exists "$app_name"; then
        exit 1
    fi

    # Remove the application using the YAML file
    local app_file="software/apps/$app_name/app.yaml"
    if kubectl delete -f "$app_file" 2>/dev/null; then
        log_success "$app_name removed successfully"
    else
        # Fallback to label-based removal in case YAML file method fails
        log_info "Trying label-based removal..."
        if kubectl delete all,ingress,configmap,secret -l "hostk8s.app=$app_name" 2>/dev/null; then
            log_success "$app_name removed successfully (label-based)"
        else
            log_warn "No resources found for app: $app_name (may already be removed)"
        fi
    fi
}

# Main function
main() {
    local operation="${1:-}"
    local app_name="${2:-}"

    # Handle different argument patterns
    if [ "$operation" = "remove" ]; then
        # Remove mode: remove [app_name]
        app_name="${app_name:-simple}"
    else
        # Deploy mode: [app_name]
        app_name="${operation:-simple}"
        operation="deploy"
    fi

    # Show help if requested
    if [ "$operation" = "-h" ] || [ "$operation" = "--help" ] || [ "$operation" = "help" ]; then
        show_usage
        exit 0
    fi

    # Ensure cluster exists and is running (skip for help)
    check_cluster_running

    # Execute the requested operation
    if [ "$operation" = "remove" ]; then
        remove_application "$app_name"
    else
        deploy_application "$app_name"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
