#!/bin/bash
# infra/scripts/flux-sync.sh - Force Flux reconciliation
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Force Flux reconciliation of GitOps resources."
    echo ""
    echo "Options:"
    echo "  --repo REPO_NAME           Sync specific GitRepository"
    echo "  --kustomization KUST_NAME  Sync specific Kustomization"
    echo "  -h, --help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Sync all repositories"
    echo "  $0 --repo my-repo              # Sync specific repository"
    echo "  $0 --kustomization my-kust     # Sync specific kustomization"
}

sync_repository() {
    local repo_name="$1"
    log_info "Syncing GitRepository: $repo_name"

    if flux reconcile source git "$repo_name"; then
        log_success "Successfully synced $repo_name"
    else
        log_error "Failed to sync $repo_name"
        return 1
    fi
}

sync_kustomization() {
    local kust_name="$1"
    log_info "Syncing Kustomization: $kust_name"

    if flux reconcile kustomization "$kust_name"; then
        log_success "Successfully synced $kust_name"
    else
        log_error "Failed to sync $kust_name"
        return 1
    fi
}

sync_all_repositories() {
    log_info "Syncing all GitRepositories (Flux will auto-reconcile kustomizations)..."

    local git_repos
    git_repos=$(flux get sources git --no-header 2>/dev/null | awk '{print $1}')

    if [ -z "$git_repos" ]; then
        log_warn "No GitRepositories found"
        return 0
    fi

    local failed_repos=()
    for repo in $git_repos; do
        echo "  → Syncing $repo"
        if ! flux reconcile source git "$repo"; then
            echo "  ❌ Failed to sync $repo"
            failed_repos+=("$repo")
        fi
    done

    if [ ${#failed_repos[@]} -gt 0 ]; then
        log_error "Failed to sync: ${failed_repos[*]}"
        return 1
    fi

    log_success "All repositories synced successfully"
}

# Main function
main() {
    local repo_name=""
    local kust_name=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                repo_name="$2"
                shift 2
                ;;
            --kustomization)
                kust_name="$2"
                shift 2
                ;;
            -h|--help|help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Ensure cluster exists and is running
    check_cluster_running

    # Check if Flux is installed
    if ! has_flux; then
        log_error "Flux is not installed in this cluster"
        log_info "Enable Flux with: make up sample"
        exit 1
    fi

    # Check if flux CLI is available
    if ! has_flux_cli; then
        log_error "flux CLI not available"
        log_info "Install with: make install"
        exit 1
    fi

    log_start "Forcing Flux reconciliation..."

    # Sync based on arguments
    if [ -n "$repo_name" ]; then
        sync_repository "$repo_name"
    elif [ -n "$kust_name" ]; then
        sync_kustomization "$kust_name"
    else
        sync_all_repositories
    fi

    log_success "Sync complete! Run 'make status' to check results."
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
