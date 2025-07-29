#!/bin/bash
# infra/scripts/install.sh - Install required dependencies
source "$(dirname "$0")/common.sh"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install required dependencies for HostK8s."
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Required tools: kind, kubectl, helm, flux, docker"
    echo ""
    echo "Supported platforms:"
    echo "  - macOS (via Homebrew)"
    echo "  - Alpine Linux (CI environment - tools should be pre-installed)"
    echo "  - Ubuntu/Debian (CI environment - tools should be pre-installed)"
}

check_tool() {
    local tool="$1"
    local install_cmd="$2"

    if command -v "$tool" >/dev/null 2>&1; then
        log_info "$tool already installed"
        return 0
    fi

    if [ -n "$install_cmd" ]; then
        log_info "Installing $tool..."
        eval "$install_cmd"
    else
        log_error "$tool not found"
        return 1
    fi
}

install_with_homebrew() {
    log_info "Using Homebrew (macOS)..."

    local tools=(
        "kind:brew install kind"
        "kubectl:brew install kubectl"
        "helm:brew install helm"
        "flux:brew install fluxcd/tap/flux"
    )

    for tool_spec in "${tools[@]}"; do
        local tool=$(echo "$tool_spec" | cut -d: -f1)
        local install_cmd=$(echo "$tool_spec" | cut -d: -f2-)
        check_tool "$tool" "$install_cmd"
    done
}

validate_ci_environment() {
    local env_name="$1"
    log_info "$env_name environment detected - dependencies should be pre-installed"

    local tools=("kind" "kubectl" "helm" "flux")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing tools in CI environment: ${missing_tools[*]}"
        return 1
    fi

    log_success "All CI dependencies verified"
}

install_dependencies() {
    log_start "Checking dependencies..."

    # Detect platform and install accordingly
    if command -v brew >/dev/null 2>&1; then
        install_with_homebrew
    elif command -v apk >/dev/null 2>&1; then
        validate_ci_environment "Alpine Linux"
    elif command -v apt >/dev/null 2>&1; then
        validate_ci_environment "Ubuntu/Debian"
    else
        log_error "Unsupported environment. Please install tools manually or use macOS with Homebrew."
        log_info "Required tools: kind, kubectl, helm, flux, docker"
        log_info "Installation guides:"
        log_info "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
        log_info "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
        log_info "  - helm: https://helm.sh/docs/intro/install/"
        log_info "  - flux: https://fluxcd.io/flux/installation/"
        return 1
    fi

    # Always check Docker separately (required on all platforms)
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not available"
        log_info "Install Docker Desktop: https://docs.docker.com/get-docker/"
        return 1
    fi

    log_success "All dependencies verified"
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

    install_dependencies
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
