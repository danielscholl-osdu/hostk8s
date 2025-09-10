# HostK8s Claude Code Instructions

## Core Purpose

HostK8s provides GitOps-based Kubernetes development environments using host-mode Kind clusters, eliminating Docker-in-Docker complexity while supporting pluggable extensions.

**Technology Stack**: Docker (host-mode), Kind, Flux v2,  NGINX
**Languages**: Bash, Powershell, Python, YAML
**Platforms**: Cross-platform support for Mac, Linux, and Windows (PowerShell)

## Critical Constraints

1. **Always use `make` commands** - Never execute scripts directly (they lack KUBECONFIG/dependencies)
2. **GitOps changes require commits** - Modifications in `software/` need Git commits to deploy
3. **Check `.env` state** - Configuration affects available operations
4. **Data persistence** - `data/` directory survives cluster operations
5. **Commit Messages** - Never make commit statments referencing `🤖 Generated with Claude Code` or `Co-Authored-By: Claude`
6. **Set Context** -- kubectl, helm, flux commands always require proper kubernetes context to be set.

## Essential Commands

```bash
Setup
  help             Show this help message
  install          Install dependencies and setup environment (Usage: make install [dev])

Infrastructure
  start            Start cluster (Usage: make start [config-name] - auto-discovers kind-*.yaml files)
  stop             Stop cluster
  up               Deploy software stack (Usage: make up [stack-name] - defaults to 'sample')
  down             Remove software stack (Usage: make down <stack-name>)
  restart          Quick cluster reset for development iteration (Usage: make restart [stack-name])
  clean            Complete cleanup (destroy cluster and data)
  status           Show cluster health and running services
  sync             Force Flux reconciliation (Usage: make sync [stack-name] or REPO=name/KUSTOMIZATION=name make sync)
  suspend          Suspend GitOps reconciliation (pause all GitRepository sources)
  resume           Resume GitOps reconciliation (restore all GitRepository sources)

Applications
  deploy           Deploy application (Usage: make deploy [app-name] [namespace] - defaults to SOFTWARE_APP or 'simple')
  remove           Remove application (Usage: make remove <app-name> [namespace] or NAMESPACE=ns make remove <app-name>)

Development Tools
  build            Build and push application from src/ (Usage: make build [src/APP_NAME] - defaults to SOFTWARE_BUILD or 'src/sample-app')
```

## Architecture Overview

```
hostk8s/
├── Makefile           # Primary interface
├── infra/             # Cluster Manifests and Scripts
├── software/          # GitOps content
│   ├── stack/         # Complete stacks
│   ├── components/    # Software components
│   └── apps/          # Individual applications
└── data/              # Persistent storage
```

**Key Files**:
- `.env` - Runtime configuration

## Working Principles

1. **Environment First**: Always check `.env` and `make status` before operations
2. **GitOps Flow**: Changes in `software/` → commit → Flux reconciles → deployed
3. **Resource Limits**: Accept Flux defaults (6GB overhead) for stability
4. **Validation**: Use `yamllint` and `shellcheck` (CI enforced)
5. **Labels**: Apply `hostk8s.app: <name>` to all resources

---

IMPORTANT: Always ensure context is properly set before executing kubectl commands. `{os.getcwd()}/data/kubeconfig/config`
