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
    if command -v pipx >/dev/null 2>&1; then
        pipx install pre-commit
    elif command -v brew >/dev/null 2>&1; then
        brew install pre-commit
    elif command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian - install via apt if pip is broken
        sudo apt update && sudo apt install -y pre-commit
    elif command -v pip3 >/dev/null 2>&1; then
        # Try pip3 if pip is broken
        pip3 install --user pre-commit
    elif command -v pip >/dev/null 2>&1; then
        pip install pre-commit
    else
        log_error "Could not install pre-commit. Please install manually:"
        log_info "   pipx install pre-commit (recommended)"
        log_info "   # or"
        log_info "   sudo apt install pre-commit (Ubuntu/Debian)"
        log_info "   # or"
        log_info "   pip3 install --user pre-commit"
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

    # Try different installation methods in order of preference
    if command -v pipx >/dev/null 2>&1; then
        pipx install yamllint
    elif command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian - install via apt if pip is broken
        sudo apt update && sudo apt install -y yamllint
    elif command -v pip3 >/dev/null 2>&1; then
        # Try pip3 if pip is broken
        pip3 install --user yamllint
    elif command -v pip >/dev/null 2>&1; then
        pip install yamllint
    else
        log_error "Could not install yamllint. Please install manually:"
        log_info "   pipx install yamllint (recommended)"
        log_info "   # or"
        log_info "   sudo apt install yamllint (Ubuntu/Debian)"
        log_info "   # or"
        log_info "   pip3 install --user yamllint"
        return 1
    fi

    log_success "yamllint installed"
}

setup_precommit_hooks() {
    if [ ! -f ".pre-commit-config.yaml" ]; then
        log_warn "No .pre-commit-config.yaml found - skipping hook installation"
        return 0
    fi

    log_info "Installing pre-commit hooks..."

    # Ensure user's local bin is in PATH for pip --user installs
    export PATH="$HOME/.local/bin:$PATH"

    if pre-commit install; then
        log_success "Pre-commit hooks installed"
    else
        log_error "Failed to install pre-commit hooks"
        return 1
    fi
}

setup_development_environment() {
    log_start "Setting up HostK8s development environment..."

    # Ensure user's local bin is in PATH for all operations
    export PATH="$HOME/.local/bin:$PATH"

    # Install tools
    install_precommit || return 1
    install_yamllint || return 1

    # Setup hooks
    setup_precommit_hooks || return 1

    log_success "Development environment setup complete!"
    log_info "You can now use 'git commit' with automatic validation"
    log_info "Manual validation: 'pre-commit run --all-files'"
    log_info ""
    log_info "Note: If commands aren't found, add to your shell profile:"
    log_info "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
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
