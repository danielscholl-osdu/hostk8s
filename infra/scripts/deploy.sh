#!/bin/bash
# infra/scripts/deploy.sh - Deploy application to cluster
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [APP_NAME]"
    echo ""
    echo "Deploy an application to the cluster."
    echo ""
    echo "Arguments:"
    echo "  APP_NAME    Application to deploy (default: sample/app1)"
    echo ""
    echo "Available applications:"
    list_available_apps | sed 's/^/  /'
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy default app (sample/app1)"
    echo "  $0 sample/app1        # Deploy basic sample app"
    echo "  $0 sample/app2        # Deploy advanced sample app"
    echo "  $0 sample/app3        # Deploy multi-service sample app"
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

# Main function
main() {
    local app_name="${1:-sample/app1}"

    # Show help if requested
    if [ "$app_name" = "-h" ] || [ "$app_name" = "--help" ] || [ "$app_name" = "help" ]; then
        show_usage
        exit 0
    fi

    # Ensure cluster exists and is running
    check_cluster_running

    # Deploy the application
    deploy_application "$app_name"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
