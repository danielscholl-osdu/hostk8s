#!/bin/bash
# infra/scripts/worktree-setup.sh - HostK8s worktree setup automation
# Usage: worktree-setup.sh [name|number]
#   worktree-setup.sh           # Creates 'dev' worktree
#   worktree-setup.sh auth      # Creates 'auth' worktree
#   worktree-setup.sh 3         # Creates dev1, dev2, dev3 worktrees

set -euo pipefail

# Disable debug mode to prevent environment variable exposure
set +x

# Source shared utilities
source "$(dirname "$0")/common.sh"

# Global variables
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GIT_USER=""
ARGUMENT=""
ARGUMENT_TYPE=""

# Port allocation strategy to prevent conflicts
# Using simple function instead of associative arrays for bash 3.2 compatibility

# Base ports for Kind cluster
BASE_API_PORT=6443
BASE_HTTP_PORT=8080
BASE_HTTPS_PORT=8443
BASE_REGISTRY_PORT=5001

# Get normalized git username
get_git_user() {
    local user_name
    user_name=$(git config user.name 2>/dev/null || echo "user")
    GIT_USER=$(echo "$user_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
    log_debug "Normalized git user: ${CYAN}${GIT_USER}${NC}"
}

# Validate input argument
validate_argument() {
    local arg="${1:-}"

    if [[ -z "$arg" ]]; then
        ARGUMENT="dev"
        ARGUMENT_TYPE="NAME"
        log_debug "No argument provided, using default: ${CYAN}dev${NC}"
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        if [[ "$arg" -lt 1 || "$arg" -gt 10 ]]; then
            log_error "Number must be between 1-10, got: $arg"
            exit 1
        fi
        ARGUMENT="$arg"
        ARGUMENT_TYPE="NUMBER"
        log_debug "Detected number argument: ${CYAN}${arg}${NC}"
    elif [[ "$arg" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        ARGUMENT="$arg"
        ARGUMENT_TYPE="NAME"
        log_debug "Detected name argument: ${CYAN}${arg}${NC}"
    else
        log_error "Invalid argument: '$arg'. Use alphanumeric characters, hyphens, or underscores only."
        exit 1
    fi
}

# Calculate unique ports for a worktree
calculate_ports() {
    local name="$1"
    local offset=0

    # Predefined offsets for common names
    case "$name" in
        "dev") offset=0 ;;
        "dev1") offset=1 ;;
        "dev2") offset=2 ;;
        "dev3") offset=3 ;;
        "dev4") offset=4 ;;
        "dev5") offset=5 ;;
        "auth") offset=10 ;;
        "backend") offset=11 ;;
        "frontend") offset=12 ;;
        "api") offset=13 ;;
        "database") offset=14 ;;
        *)
            # Calculate based on name hash for unknown names
            offset=$(( $(echo -n "$name" | cksum | cut -d' ' -f1) % 50 + 20 ))
            ;;
    esac

    echo "$offset"
}

# Create custom Kind config with unique ports
create_kind_config() {
    local name="$1"
    local worktree_dir="$2"
    local offset
    offset=$(calculate_ports "$name")

    local api_port=$((BASE_API_PORT + offset))
    local http_port=$((BASE_HTTP_PORT + offset))
    local https_port=$((BASE_HTTPS_PORT + offset))
    local registry_port=$((BASE_REGISTRY_PORT + offset))

    log_debug "Allocating ports for ${CYAN}${name}${NC}: API=${api_port}, HTTP=${http_port}, HTTPS=${https_port}, Registry=${registry_port}"

    # Create extension directory and copy base config
    mkdir -p "$worktree_dir/infra/kubernetes/extension"
    cp "$PROJECT_ROOT/infra/kubernetes/kind-config.yaml" "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml"

    # Update cluster name and ports
    sed -i.bak "s/name: hostk8s/name: ${name}/" "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml"
    sed -i.bak "s/containerPort: 80/containerPort: 80/" "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml"
    sed -i.bak "s/hostPort: 8080/hostPort: ${http_port}/" "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml"
    sed -i.bak "s/containerPort: 443/containerPort: 443/" "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml"
    sed -i.bak "s/hostPort: 8443/hostPort: ${https_port}/" "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml"

    # Clean up backup files
    rm -f "$worktree_dir/infra/kubernetes/extension/kind-${name}.yaml.bak"

    log_debug "Created custom Kind config: ${CYAN}infra/kubernetes/extension/kind-${name}.yaml${NC}"
}

# Configure environment for a worktree
configure_environment() {
    local name="$1"
    local worktree_dir="$2"

    log_debug "Configuring environment for worktree: ${CYAN}${name}${NC}"

    # Copy environment template
    cp "$PROJECT_ROOT/.env.example" "$worktree_dir/.env"

    # Update configuration - handle both commented and uncommented lines
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed syntax
        sed -i '' "s/^# *CLUSTER_NAME=.*/CLUSTER_NAME=${name}/" "$worktree_dir/.env"
        sed -i '' "s/^CLUSTER_NAME=.*/CLUSTER_NAME=${name}/" "$worktree_dir/.env"
        sed -i '' "s/^# *GITOPS_BRANCH=.*/GITOPS_BRANCH=user\/${GIT_USER}\/${name}/" "$worktree_dir/.env"
        sed -i '' "s/^GITOPS_BRANCH=.*/GITOPS_BRANCH=user\/${GIT_USER}\/${name}/" "$worktree_dir/.env"
        sed -i '' "s/^# *FLUX_ENABLED=.*/FLUX_ENABLED=true/" "$worktree_dir/.env"
        sed -i '' "s/^FLUX_ENABLED=.*/FLUX_ENABLED=true/" "$worktree_dir/.env"
        echo "KIND_CONFIG=extension/${name}" >> "$worktree_dir/.env"
    else
        # Linux sed syntax
        sed -i "s/^# *CLUSTER_NAME=.*/CLUSTER_NAME=${name}/" "$worktree_dir/.env"
        sed -i "s/^CLUSTER_NAME=.*/CLUSTER_NAME=${name}/" "$worktree_dir/.env"
        sed -i "s/^# *GITOPS_BRANCH=.*/GITOPS_BRANCH=user\/${GIT_USER}\/${name}/" "$worktree_dir/.env"
        sed -i "s/^GITOPS_BRANCH=.*/GITOPS_BRANCH=user\/${GIT_USER}\/${name}/" "$worktree_dir/.env"
        sed -i "s/^# *FLUX_ENABLED=.*/FLUX_ENABLED=true/" "$worktree_dir/.env"
        sed -i "s/^FLUX_ENABLED=.*/FLUX_ENABLED=true/" "$worktree_dir/.env"
        echo "KIND_CONFIG=extension/${name}" >> "$worktree_dir/.env"
    fi

    log_success "Environment configured for ${CYAN}${name}${NC}"
}

# Create a single worktree
create_worktree() {
    local name="$1"
    local worktree_dir="$PROJECT_ROOT/trees/$name"
    local branch_name="user/${GIT_USER}/${name}"

    log_info "Creating worktree: ${CYAN}${name}${NC}"

    # Create trees directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/trees"

    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        log_debug "Branch ${CYAN}${branch_name}${NC} already exists, using existing branch"
        git worktree add "$worktree_dir" "$branch_name"
    else
        log_debug "Creating new branch: ${CYAN}${branch_name}${NC}"
        git worktree add -b "$branch_name" "$worktree_dir"
    fi

    # Configure environment
    configure_environment "$name" "$worktree_dir"

    # Create custom Kind config
    create_kind_config "$name" "$worktree_dir"

    # Commit and push if new branch
    cd "$worktree_dir"
    if ! git ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
        log_debug "Pushing new branch to remote"
        git add .env "infra/kubernetes/extension/kind-${name}.yaml" 2>/dev/null || true
        git commit --allow-empty -m "Initialize ${name} development branch

- Environment configured for ${name} cluster
- Custom Kind config with unique ports
- GitOps enabled for branch ${branch_name}"
        git push -u origin "$branch_name"
    fi

    # Start cluster
    log_info "Starting cluster: ${CYAN}${name}${NC}"
    make up

    cd "$PROJECT_ROOT"
    log_success "Worktree ${CYAN}${name}${NC} created and cluster started"
}

# Create multiple numbered worktrees
create_numbered_worktrees() {
    local count="$1"

    log_info "Creating ${CYAN}${count}${NC} numbered worktrees"

    for i in $(seq 1 "$count"); do
        local name="dev${i}"
        create_worktree "$name"
    done

    log_success "All ${CYAN}${count}${NC} worktrees created and clusters started"
}

# Show usage information
show_usage() {
    echo "Usage: $0 [name|number]"
    echo ""
    echo "Examples:"
    echo "  $0           # Creates 'dev' worktree"
    echo "  $0 auth      # Creates 'auth' worktree"
    echo "  $0 3         # Creates dev1, dev2, dev3 worktrees"
    echo ""
    echo "Each worktree gets:"
    echo "  - Isolated git branch (user/\$GIT_USER/name)"
    echo "  - Dedicated cluster with unique ports"
    echo "  - GitOps configuration"
    echo "  - Custom environment settings"
}

# Validate prerequisites
validate_prerequisites() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        exit 1
    fi

    # Check if we're in the project root
    if [[ ! -f "Makefile" ]] || [[ ! -d "infra" ]]; then
        log_error "Must be run from HostK8s project root"
        exit 1
    fi

    # Check for required tools
    for tool in git make; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Missing required tool: $tool"
            exit 1
        fi
    done
}

# Main execution
main() {
    local arg="${1:-}"

    if [[ "$arg" == "-h" ]] || [[ "$arg" == "--help" ]]; then
        show_usage
        exit 0
    fi

    log_start "HostK8s Worktree Setup"

    # Validate environment
    validate_prerequisites

    # Get git user and validate argument
    get_git_user
    validate_argument "$arg"

    # Execute based on argument type
    case "$ARGUMENT_TYPE" in
        "NAME")
            create_worktree "$ARGUMENT"
            ;;
        "NUMBER")
            create_numbered_worktrees "$ARGUMENT"
            ;;
        *)
            log_error "Unknown argument type: $ARGUMENT_TYPE"
            exit 1
            ;;
    esac

    # Show final status
    log_info "Worktree setup complete!"
    log_info "Active worktrees:"
    git worktree list | while read -r line; do
        log_info "  ${CYAN}${line}${NC}"
    done

    log_info "To switch between worktrees:"
    log_info "  ${CYAN}cd trees/[worktree-name]${NC}"
    log_info "  ${CYAN}make status${NC}"
}

# Execute main function with all arguments
main "$@"
