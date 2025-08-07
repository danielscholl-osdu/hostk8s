# HostK8s Copilot Instructions

## Overview
HostK8s is a **host-mode Kubernetes development platform** built on Kind that removes Docker-in-Docker complexity and supports GitOps-based software stacks for reproducible development environments.

**Key Features:**
- **Host-Mode:** Kind runs directly on host Docker daemon
- **GitOps Stacks:** Complete app + infra deployments via Flux
- **Extensions:** Filesystem- or Git-based pluggable components
- **Make Interface:** Unified commands for cluster and app management

## Essential Workflows

**Always use `make` commands** - they manage KUBECONFIG and dependencies automatically:

```bash
make help          # Show available commands
make start         # Start basic cluster
make up sample     # Cluster + GitOps stack
make deploy simple # Deploy single app
make status        # Cluster health and service status
make stop          # Stop cluster
make clean         # Tear down cluster
```

**Configuration:** Set variables in `.env` (see `.env.example`):
- `FLUX_ENABLED=true` → Enable GitOps
- `METALLB_ENABLED=true` → LoadBalancer support
- `INGRESS_ENABLED=true` → Ingress controllers
- `GITOPS_REPO=<url>` → External GitOps stack source

## Architecture

**Abstraction Layers:**
1. **Make Interface** – CLI commands, KUBECONFIG auto-handling
2. **Scripts** – Single-purpose, sourced from `common.sh`
3. **Shared Utilities** – Common orchestration helpers

**Software Stack Structure:**
```
software/stack/example/
├── kustomization.yaml
├── repository.yaml
├── stack.yaml
├── components/
└── applications/
```

## Extensions

**Filesystem-Based:**
```bash
make deploy my-app            # software/apps/my-app/kustomization.yaml
make build src/my-app
KIND_CONFIG=extension/custom   # infra/kubernetes/extension/kind-custom.yaml
```

**Git-Based:**
```bash
export GITOPS_REPO=https://github.com/team/stack
make up extension
```

## Coding Conventions

- **YAML:** Validate with `yamllint -c .yamllint.yaml .` (CI enforced)
- **Labels:** Use `hostk8s.app: <name>` for all K8s resources
- **Scripts:** Use `set -euo pipefail` and `common.sh` logging functions

## Debugging Priority

**Use tools in this order:**

1. **Make commands** for workflows and health checks:
   ```bash
   make status
   make logs
   make sync
   ```

2. **MCP tools** for detailed Kubernetes/GitOps analysis:
   - `mcp_kubernetes_kubectl_get` → List resources
   - `mcp_kubernetes_kubectl_describe` → Describe resources
   - `mcp_kubernetes_kubectl_logs` → Fetch logs
   - `mcp_flux-operator_get_flux_instance` → Flux status
   - `mcp_flux-operator_reconcile_flux_kustomization` → Force sync

3. **Raw CLI** only as fallback:
   ```bash
   kubectl get events --sort-by='.lastTimestamp'
   flux get all
   ```
