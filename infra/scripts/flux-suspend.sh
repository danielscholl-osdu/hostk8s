#!/bin/bash
# infra/scripts/flux-suspend.sh - Suspend/Resume Flux GitRepository sources
set -euo pipefail
set +x  # Prevent secret exposure
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [suspend|resume]"
    echo ""
    echo "Suspend or resume all Flux GitRepository sources."
    echo ""
    echo "Commands:"
    echo "  suspend    Suspend all GitRepository sources (pause GitOps)"
    echo "  resume     Resume all GitRepository sources (restore GitOps)"
    echo "  -h, --help Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 suspend     # Pause all GitOps reconciliation"
    echo "  $0 resume      # Restore all GitOps reconciliation"
}

get_git_repositories() {
    local git_repos
    git_repos=$(flux get sources git --no-header 2>/dev/null | awk '{print $1}')
    echo "$git_repos"
}

suspend_repositories() {
    log_info "Suspending all GitRepository sources..."

    local git_repos
    git_repos=$(get_git_repositories)

    if [ -z "$git_repos" ]; then
        log_warn "No GitRepositories found"
        return 0
    fi

    local failed_repos=()
    local suspended_count=0

    for repo in $git_repos; do
        log_info "  → Suspending repository: $repo"
        if flux suspend source git "$repo" >/dev/null 2>&1; then
            ((suspended_count++))
        else
            log_error "  ❌ Failed to suspend $repo"
            failed_repos+=("$repo")
        fi
    done

    if [ ${#failed_repos[@]} -gt 0 ]; then
        log_error "Failed to suspend repositories: ${failed_repos[*]}"
        return 1
    fi

    log_success "Successfully suspended $suspended_count GitRepository sources"
    log_info "GitOps reconciliation is now paused. Use 'make resume' to restore."
}

resume_repositories() {
    log_info "Resuming all GitRepository sources..."

    local git_repos
    git_repos=$(get_git_repositories)

    if [ -z "$git_repos" ]; then
        log_warn "No GitRepositories found"
        return 0
    fi

    local failed_repos=()
    local resumed_count=0

    for repo in $git_repos; do
        log_info "  → Resuming repository: $repo"
        if flux resume source git "$repo" >/dev/null 2>&1; then
            ((resumed_count++))
        else
            log_error "  ❌ Failed to resume $repo"
            failed_repos+=("$repo")
        fi
    done

    if [ ${#failed_repos[@]} -gt 0 ]; then
        log_error "Failed to resume repositories: ${failed_repos[*]}"
        return 1
    fi

    log_success "Successfully resumed $resumed_count GitRepository sources"
    log_info "GitOps reconciliation is now active. Use 'make sync' to force reconciliation."
}

# Main function
main() {
    local action=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            suspend)
                action="suspend"
                shift
                ;;
            resume)
                action="resume"
                shift
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

    if [ -z "$action" ]; then
        log_error "Missing action: suspend or resume"
        show_usage
        exit 1
    fi

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

    log_start "Managing GitRepository sources..."

    # Execute action
    if [ "$action" = "suspend" ]; then
        suspend_repositories
    elif [ "$action" = "resume" ]; then
        resume_repositories
    fi

    log_success "Operation complete! Run 'make status' to check results."
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
