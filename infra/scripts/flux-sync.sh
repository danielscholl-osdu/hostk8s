#!/bin/bash
# infra/scripts/flux-sync.sh - Force Flux reconciliation
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Force Flux reconciliation of GitOps resources."
    echo ""
    echo "Options:"
    echo "  --stack STACK_NAME         Sync specific stack (source + kustomization)"
    echo "  --repo REPO_NAME           Sync specific GitRepository"
    echo "  --kustomization KUST_NAME  Sync specific Kustomization"
    echo "  -h, --help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                              # Sync all sources and stacks"
    echo "  $0 --stack sample               # Sync source + sample stack"
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

sync_stack() {
    local stack_name="$1"
    log_info "Syncing stack: $stack_name"

    # First sync the git source
    log_info "  → Syncing flux-system repository"
    if ! flux reconcile source git flux-system; then
        log_error "Failed to sync flux-system repository"
        return 1
    fi

    # Then sync the bootstrap stack kustomization with source
    local bootstrap_kust="bootstrap-stack"
    log_info "  → Syncing $bootstrap_kust kustomization"
    if flux reconcile kustomization "$bootstrap_kust" --with-source; then
        log_success "Successfully synced stack: $stack_name"
    else
        log_error "Failed to sync stack: $stack_name"
        return 1
    fi
}

sync_all_repositories() {
    log_info "Syncing all GitRepositories and stack kustomizations..."

    local git_repos
    git_repos=$(flux get sources git --no-header 2>/dev/null | awk '{print $1}')

    if [ -z "$git_repos" ]; then
        log_warn "No GitRepositories found"
        return 0
    fi

    local failed_repos=()
    for repo in $git_repos; do
        echo "  → Syncing repository: $repo"
        if ! flux reconcile source git "$repo"; then
            echo "  ❌ Failed to sync $repo"
            failed_repos+=("$repo")
        fi
    done

    # Sync stack kustomizations (bootstrap-stack and any others)
    local stack_kustomizations
    stack_kustomizations=$(flux get kustomizations --no-header 2>/dev/null | awk '$1 ~ /bootstrap-stack|stack$/ {print $1}')

    local failed_kustomizations=()
    for kust in $stack_kustomizations; do
        echo "  → Syncing stack kustomization: $kust"
        if ! flux reconcile kustomization "$kust" --with-source; then
            echo "  ❌ Failed to sync $kust"
            failed_kustomizations+=("$kust")
        fi
    done

    if [ ${#failed_repos[@]} -gt 0 ] || [ ${#failed_kustomizations[@]} -gt 0 ]; then
        [ ${#failed_repos[@]} -gt 0 ] && log_error "Failed to sync repositories: ${failed_repos[*]}"
        [ ${#failed_kustomizations[@]} -gt 0 ] && log_error "Failed to sync kustomizations: ${failed_kustomizations[*]}"
        return 1
    fi

    log_success "All repositories and stack kustomizations synced successfully"
}

# Main function
main() {
    local repo_name=""
    local kust_name=""
    local stack_name=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stack)
                stack_name="$2"
                shift 2
                ;;
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
    if [ -n "$stack_name" ]; then
        sync_stack "$stack_name"
    elif [ -n "$repo_name" ]; then
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
