# HostK8s Claude Code Instructions

## Core Purpose

HostK8s provides GitOps-based Kubernetes development environments using host-mode Kind clusters, eliminating Docker-in-Docker complexity while supporting pluggable extensions.

**Technology Stack**: Docker (host-mode), Kind, Flux v2, MetalLB, NGINX
**Languages**: Bash, YAML

## Critical Constraints

1. **Always use `make` commands** - Never execute scripts directly (they lack KUBECONFIG/dependencies)
2. **GitOps changes require commits** - Modifications in `software/` need Git commits to deploy
3. **Check `.env` state** - Configuration affects available operations
4. **Data persistence** - `data/` directory survives cluster operations
5. **Commit Messages** - Never make commit statments referencing `🤖 Generated with Claude Code` or `Co-Authored-By: Claude`

## SubAgent Delegation

**Decision Rule**: Delegate based on problem domain, not file location.

| Agent | Use For |
|-------|---------|
| `cluster-agent` | Infrastructure issues (Kind, networking, resources, RBAC) |
| `software-agent` | GitOps/Flux issues (reconciliation, repository structure) |
| `gitops-committer` | ANY changes requiring Git commits (software/ modifications) |
| `developer-agent` | Delegating SWE activities to a worktree autonomous flow |

**Key Pattern**: If changes need Git commits to take effect → use `gitops-committer` immediately

## Essential Commands

```bash
# Setup
make install       # Install dependencies
make install dev   # Setup dev environment

# Infrastructure
make start         # Start cluster
make stop          # Stop cluster
make up <stack>    # Deploy software stack
make down <stack>  # Remove software stack
make clean         # Complete cleanup

# Applications
make deploy <app>  # Deploy application
make remove <app>  # Remove application

# Operations
make status        # Check health
make sync          # Force GitOps sync

# Extensions
make deploy extension/<name>     # Deploy extension app
make up extension/<stack>        # Deploy extension stack
```

## Architecture Overview

```
hostk8s/
├── Makefile           # Primary interface
├── scripts/           # Implementation (via common.sh)
├── software/          # GitOps content
│   ├── stack/         # Complete stacks
│   └── apps/          # Individual applications
└── data/              # Persistent storage
```

**Key Files**:
- `.env` - Runtime configuration
- `scripts/common.sh` - Shared utilities
- `software/stack/*/kustomization.yaml` - Stack definitions

## Working Principles

1. **Environment First**: Always check `.env` and `make status` before operations
2. **GitOps Flow**: Changes in `software/` → commit → Flux reconciles → deployed
3. **Resource Limits**: Accept Flux defaults (6GB overhead) for stability
4. **Validation**: Use `yamllint` and `shellcheck` (CI enforced)
5. **Labels**: Apply `hostk8s.app: <name>` to all resources

## Error Recovery

1. **Diagnose**: `make status` → identify domain (infrastructure vs software)
2. **Delegate**: Infrastructure → `cluster-agent`, GitOps → `software-agent`
3. **Force Sync**: `make sync` for reconciliation issues
4. **MCP Tools**: Use for detailed analysis when Make commands insufficient

## Extension Patterns

**Filesystem**: Place in `software/apps/extension/` or `infra/kubernetes/extension/`
**Git-Based**: Set `GITOPS_REPO` environment variable
**Custom Kind**: Use `KIND_CONFIG=extension/<name>`
