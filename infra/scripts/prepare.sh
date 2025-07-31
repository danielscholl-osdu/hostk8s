#!/bin/bash
# infra/scripts/prepare.sh - Setup development environment
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Setup HostK8s development environment (pre-commit, yamllint, hooks)."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Tools installed:"
    echo "  - pre-commit (code quality hooks)"
    echo "  - yamllint (YAML validation)"
    echo "  - pre-commit hooks (configured in .pre-commit-config.yaml)"
}

install_precommit() {
    if command -v pre-commit >/dev/null 2>&1; then
        log_info "pre-commit already installed"
        return 0
    fi

    log_info "Installing pre-commit..."

    # Try different installation methods in order of preference
    if command -v pip >/dev/null 2>&1; then
        pip install pre-commit
    elif command -v pipx >/dev/null 2>&1; then
        pipx install pre-commit
    elif command -v brew >/dev/null 2>&1; then
        brew install pre-commit
    else
        log_error "Could not install pre-commit. Please install manually:"
        log_info "   pip install pre-commit"
        log_info "   # or"
        log_info "   pipx install pre-commit"
        log_info "   # or"
        log_info "   brew install pre-commit"
        return 1
    fi

    log_success "pre-commit installed"
}

install_yamllint() {
    if command -v yamllint >/dev/null 2>&1; then
        log_info "yamllint already installed"
        return 0
    fi

    log_info "Installing yamllint..."

    if command -v pip >/dev/null 2>&1; then
        pip install yamllint
        log_success "yamllint installed"
    else
        log_error "pip not available - cannot install yamllint"
        log_info "Please install yamllint manually: pip install yamllint"
        return 1
    fi
}

setup_precommit_hooks() {
    if [ ! -f ".pre-commit-config.yaml" ]; then
        log_warn "No .pre-commit-config.yaml found - skipping hook installation"
        return 0
    fi

    log_info "Installing pre-commit hooks..."

    if pre-commit install; then
        log_success "Pre-commit hooks installed"
    else
        log_error "Failed to install pre-commit hooks"
        return 1
    fi
}

setup_development_environment() {
    log_start "Setting up HostK8s development environment..."

    # Install tools
    install_precommit || return 1
    install_yamllint || return 1

    # Setup hooks
    setup_precommit_hooks || return 1

    log_success "Development environment setup complete!"
    log_info "You can now use 'git commit' with automatic validation"
    log_info "Manual validation: 'pre-commit run --all-files'"
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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

    setup_development_environment
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
