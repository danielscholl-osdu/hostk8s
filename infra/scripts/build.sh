#!/bin/bash
# infra/scripts/build.sh - Build and push application from src/
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 APP_PATH"
    echo ""
    echo "Build and push application from src/ directory."
    echo ""
    echo "Arguments:"
    echo "  APP_PATH    Path to application directory (e.g., src/registry-demo)"
    echo ""
    echo "Requirements:"
    echo "  - Directory must exist"
    echo "  - Must contain docker-compose.yml"
    echo "  - Cluster must be running"
    echo ""
    list_available_source_apps
    echo ""
    echo "Examples:"
    echo "  $0 src/registry-demo    # Build registry demo app"
}

list_available_source_apps() {
    echo "Available applications:"
    if find src/ -name "docker-compose.yml" -exec dirname {} \; 2>/dev/null | sort; then
        :
    else
        echo "  No applications found in src/"
    fi
}

validate_app_path() {
    local app_path="$1"

    if [ -z "$app_path" ]; then
        log_error "No application path provided"
        show_usage
        return 1
    fi

    if [ ! -d "$app_path" ]; then
        log_error "Directory not found: $app_path"
        list_available_source_apps
        return 1
    fi

    if [ ! -f "$app_path/docker-compose.yml" ]; then
        log_error "No docker-compose.yml found in $app_path"
        log_info "Expected: $app_path/docker-compose.yml"
        return 1
    fi

    return 0
}

build_and_push_app() {
    local app_path="$1"

    log_start "Building application: $app_path"

    # Change to app directory
    cd "$app_path" || {
        log_error "Failed to change to directory: $app_path"
        return 1
    }

    # Set build metadata
    local build_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local build_version="1.0.0"

    export BUILD_DATE="$build_date"
    export BUILD_VERSION="$build_version"

    log_info "Build date: $build_date"
    log_info "Version: $build_version"

    # Build the application
    log_info "Building Docker images..."
    if ! docker compose build; then
        log_error "Docker build failed"
        return 1
    fi

    # Push to registry
    log_info "Pushing to registry..."
    if ! docker compose push; then
        log_error "Docker push failed"
        return 1
    fi

    log_success "Build and push complete"

    # Show next steps
    local app_name=$(basename "$app_path")
    echo ""
    log_info "Next steps:"
    echo "1. Deploy: make deploy sample/$app_name"
    echo "2. Status: make status"
    echo "3. Access: check software/apps/sample/$app_name/README.md"
}

# Main function
main() {
    local app_path="$1"

    # Show help if requested
    if [ "$app_path" = "-h" ] || [ "$app_path" = "--help" ] || [ "$app_path" = "help" ]; then
        show_usage
        exit 0
    fi

    # Ensure cluster exists and is running
    check_cluster_running

    # Validate the application path
    if ! validate_app_path "$app_path"; then
        exit 1
    fi

    # Build and push the application
    build_and_push_app "$app_path"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
