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
    echo "Required tools: kind, kubectl, helm, flux, flux-operator-mcp, yq, docker"
    echo ""
    echo "Supported package managers:"
    echo "  - Homebrew (brew) - macOS/Linux"
    echo "  - APT (apt) - Ubuntu/Debian"
    echo "  - APK (apk) - Alpine Linux"
}

check_tool() {
    local tool="$1"
    local install_cmd="$2"

    if command -v "$tool" >/dev/null 2>&1; then
        local version=""
        case "$tool" in
            "kind")
                version=$(kind version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "")
                ;;
            "kubectl")
                version=$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | cut -d'"' -f4 | sed 's/gitVersion://' | tr -d ' ' || echo "")
                ;;
            "helm")
                version=$(helm version --template='{{.Version}}' 2>/dev/null || echo "")
                ;;
            "flux")
                version=$(flux version --client 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
                ;;
            "flux-operator-mcp")
                version=$(flux-operator-mcp --version 2>/dev/null | head -1 | cut -d' ' -f3 2>/dev/null || echo "")
            "yq")
                version=$(yq --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
                ;;
        esac

        if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
            if [ -n "$version" ]; then
                log_debug "  $tool: ${CYAN}$version${NC}"
            else
                log_debug "  $tool: ${CYAN}installed${NC}"
            fi
        fi
        return 0
    fi

    if [ -n "$install_cmd" ]; then
        log_debug "Installing $tool..."
        eval "$install_cmd"
        # Check version after installation
        local version=""
        case "$tool" in
            "kind")
                version=$(kind version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "")
                ;;
            "kubectl")
                version=$(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | cut -d'"' -f4 | sed 's/gitVersion://' | tr -d ' ' || echo "")
                ;;
            "helm")
                version=$(helm version --template='{{.Version}}' 2>/dev/null || echo "")
                ;;
            "flux")
                version=$(flux version --client 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
                ;;
            "flux-operator-mcp")
                version=$(flux-operator-mcp --version 2>/dev/null | head -1 | cut -d' ' -f3 2>/dev/null || echo "")
            "yq")
                version=$(yq --version 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "")
                ;;
        esac

        if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
            if [ -n "$version" ]; then
                log_debug "  $tool: ${CYAN}$version${NC}"
            else
                log_debug "  $tool: ${CYAN}installed${NC}"
            fi
        fi
    else
        log_error "$tool not found"
        return 1
    fi
}

install_with_homebrew() {
    log_info "Tools"

    local tools=(
        "kind:brew install kind"
        "kubectl:brew install kubectl"
        "helm:brew install helm"
        "flux:brew install fluxcd/tap/flux"
        "flux-operator-mcp:brew install controlplaneio-fluxcd/tap/flux-operator-mcp"
        "yq:brew install yq"
    )

    for tool_spec in "${tools[@]}"; do
        local tool=$(echo "$tool_spec" | cut -d: -f1)
        local install_cmd=$(echo "$tool_spec" | cut -d: -f2-)
        check_tool "$tool" "$install_cmd"
    done
}

install_with_apt() {
    log_info "Tools"

    # Update package list
    sudo apt update

    local tools=(
        "kind:curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
        "kubectl:sudo apt install -y kubectl"
        "helm:curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null && echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main' | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list && sudo apt update && sudo apt install -y helm"
        "flux:curl -s https://fluxcd.io/install.sh | sudo bash"
        "flux-operator-mcp:curl -sL https://github.com/controlplaneio-fluxcd/flux-operator-mcp/releases/latest/download/flux-operator-mcp-linux-amd64.tar.gz | tar xz && sudo mv flux-operator-mcp /usr/local/bin/"
        "yq:sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    )

    for tool_spec in "${tools[@]}"; do
        local tool=$(echo "$tool_spec" | cut -d: -f1)
        local install_cmd=$(echo "$tool_spec" | cut -d: -f2-)
        check_tool "$tool" "$install_cmd"
    done
}

install_with_apk() {
    log_info "Tools"

    local tools=(
        "kind:curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"
        "kubectl:sudo apk add --no-cache kubectl"
        "helm:sudo apk add --no-cache helm"
        "flux:curl -s https://fluxcd.io/install.sh | sudo sh"
        "flux-operator-mcp:curl -sL https://github.com/controlplaneio-fluxcd/flux-operator-mcp/releases/latest/download/flux-operator-mcp-linux-amd64.tar.gz | tar xz && sudo mv flux-operator-mcp /usr/local/bin/"
        "yq:sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    )

    for tool_spec in "${tools[@]}"; do
        local tool=$(echo "$tool_spec" | cut -d: -f1)
        local install_cmd=$(echo "$tool_spec" | cut -d: -f2-)
        check_tool "$tool" "$install_cmd"
    done
}

validate_ci_environment() {
    local env_name="$1"
    log_debug "$env_name environment detected - dependencies should be pre-installed"

    local tools=("kind" "kubectl" "helm" "flux" "flux-operator-mcp" "yq")
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
    log_info "Checking dependencies..."
    log_info "------------------------"
    log_info "Dependency Configuration"

    # Select package manager based on PACKAGE_MANAGER setting
    if [ -z "$PACKAGE_MANAGER" ]; then
        # Auto-detect: prefer brew, then native
        if command -v brew >/dev/null 2>&1; then
            log_info "  Package Manager: Homebrew (auto-detected)"
            log_info "  Platform: $(uname -s)"
            log_info "------------------------"
            install_with_homebrew
        elif command -v apt >/dev/null 2>&1; then
            log_info "  Package Manager: APT (auto-detected)"
            log_info "  Platform: $(uname -s)"
            log_info "------------------------"
            install_with_apt
        elif command -v apk >/dev/null 2>&1; then
            if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
                log_debug "  Package Manager: ${CYAN}APK${NC} (auto-detected)"
                log_debug "  Platform: ${CYAN}$(uname -s)${NC}"
                log_debug "------------------------"
            fi
            install_with_apk
        else
            if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
                log_debug "------------------------"
            fi
            log_error "No supported package manager found (brew, apt, or apk)."
            log_info "Required tools: kind, kubectl, helm, flux, flux-operator-mcp, yq, docker"
            log_info "Installation guides:"
            log_info "  - kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
            log_info "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
            log_info "  - helm: https://helm.sh/docs/intro/install/"
            log_info "  - flux: https://fluxcd.io/flux/installation/"
            log_info "  - flux-operator-mcp: https://fluxcd.control-plane.io/mcp/install/"
            return 1
        fi
    elif [ "$PACKAGE_MANAGER" = "brew" ]; then
        # Force Homebrew
        if command -v brew >/dev/null 2>&1; then
            if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
                log_debug "  Package Manager: ${CYAN}Homebrew${NC} (forced)"
                log_debug "  Platform: ${CYAN}$(uname -s)${NC}"
                log_debug "------------------------"
            fi
            install_with_homebrew
        else
            log_error "Homebrew not available but PACKAGE_MANAGER=brew is set"
            log_info "Install Homebrew: https://brew.sh/"
            return 1
        fi
    elif [ "$PACKAGE_MANAGER" = "native" ]; then
        # Force native package manager
        if command -v apt >/dev/null 2>&1; then
            if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
                log_debug "  Package Manager: ${CYAN}APT${NC} (native)"
                log_debug "  Platform: ${CYAN}$(uname -s)${NC}"
                log_debug "------------------------"
            fi
            install_with_apt
        elif command -v apk >/dev/null 2>&1; then
            if [ "${LOG_LEVEL:-debug}" = "debug" ]; then
                log_debug "  Package Manager: ${CYAN}APK${NC} (native)"
                log_debug "  Platform: ${CYAN}$(uname -s)${NC}"
                log_debug "------------------------"
            fi
            install_with_apk
        else
            log_error "No native package manager found (apt or apk) but PACKAGE_MANAGER=native is set"
            return 1
        fi
    else
        log_error "Invalid PACKAGE_MANAGER value: '$PACKAGE_MANAGER'"
        log_info "Valid options: brew, native"
        return 1
    fi

    # Always check Docker separately (required on all platforms)
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not available"
        log_info "Install Docker Desktop: https://docs.docker.com/get-docker/"
        return 1
    fi

    log_info "------------------------"
    log_info "All dependencies verified"
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
