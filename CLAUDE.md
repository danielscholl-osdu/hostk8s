# HostK8s Claude Code Instructions

**applyTo**: `"**/*.{yaml,yml,sh,md,go}"`

## Context and Constraints

**What HostK8s Does:**
- Eliminates Docker-in-Docker complexity through host-mode Kind clusters
- Provides GitOps-based reproducible development environments
- Supports pluggable extensions via filesystem or Git sources
- Manages complete application + infrastructure deployments

**What HostK8s Does NOT Do:**
- Production Kubernetes cluster management
- Multi-cluster orchestration
- Service mesh configuration
- CI/CD pipeline execution (provides foundation only)

**Technology Stack:**
- **Container Runtime**: Docker (host-mode)
- **Kubernetes**: Kind clusters
- **GitOps**: Flux v2
- **Load Balancing**: MetalLB
- **Ingress**: NGINX or Traefik
- **Languages**: Bash, Go, YAML
- **Validation**: yamllint, shellcheck

## SubAgent Delegation Strategy

**Available Specialists:**
- `cluster-agent` - Infrastructure Kubernetes specialist for HostK8s clusters
- `software-agent` - GitOps/Flux Software specialist for HostK8s clusters

**Delegation Decision Matrix:**

**Use `cluster-agent` for:**
- Kind cluster configuration and management
- Kubernetes resource troubleshooting (pods, services, deployments)
- Infrastructure component setup (MetalLB, ingress controllers)
- Node and cluster-level networking issues
- Storage and volume management
- RBAC and security policy configuration
- Performance monitoring and resource allocation

**Use `software-agent` for:**
- GitOps repository structure and Flux configuration
- Kustomization and Helm chart management
- Application deployment specifications
- Software stack composition and dependencies
- Flux reconciliation and sync issues
- Repository source management
- Application-level configuration and secrets

**Self-Handle (No Delegation) for:**
- Make command orchestration and workflow coordination
- Documentation updates and markdown file management
- Cross-cutting concerns that span both infrastructure and software
- Initial problem diagnosis before determining specialization needed
- Simple status checks and basic troubleshooting

**Delegation Patterns:**
```bash
# Infrastructure issues → cluster-agent
"Kind cluster won't start" → cluster-agent
"LoadBalancer service not getting external IP" → cluster-agent
"Pod stuck in pending state" → cluster-agent

# Software deployment issues → software-agent
"Flux kustomization failing to reconcile" → software-agent
"GitOps repository structure optimization" → software-agent
"Application helm chart not deploying" → software-agent

# Workflow coordination → self-handle
"Run full cluster setup with sample stack" → self-handle with make commands
"Generate project documentation" → self-handle
"Diagnose whether issue is infrastructure or software" → self-handle first
```

**Critical: Always use `make` commands** - direct script execution will fail due to missing KUBECONFIG and dependency management:

**Constraint**: Never run scripts in `scripts/` directory directly
**Reason**: Make targets handle environment setup, KUBECONFIG paths, and dependency validation
**Pattern**: All operations must go through Make interface

## Task-Specific Execution Patterns

**Common Tasks and Exact Commands:**

**Cluster Management:**
```bash
make install       # Install dependencies (kind, kubectl, helm, flux)
make up            # Start basic cluster
make up sample     # Cluster + GitOps stack
make clean         # Tear down cluster
```

**Application Deployment:**
```bash
make deploy simple              # Deploy single app
make deploy extension/my-app    # Deploy filesystem extension
make build src/extension/my-app # Build custom extension
```

**Status and Debugging:**
```bash
make status        # Cluster health and service status
make logs          # Aggregate log viewing
make sync          # Force GitOps synchronization
```

**Configuration:** Set variables in `.env` (see `.env.example`):
- `FLUX_ENABLED=true` → Enable GitOps
- `METALLB_ENABLED=true` → LoadBalancer support
- `INGRESS_ENABLED=true` → Ingress controllers
- `GITOPS_REPO=<url>` → External GitOps stack source

## Environment State Awareness

**Always check current state before operations:**
```bash
cat .env               # Active configuration
make status            # Cluster and service health
```

**Key states that affect available operations:**
- No `.env` file → Using defaults from `.env.example`
- `FLUX_ENABLED=false` → Manual deployment only, no GitOps commands
- `METALLB_ENABLED=false` → No LoadBalancer service support
- `INGRESS_ENABLED=false` → No ingress resources can be deployed

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

**Data Persistence:**
- **Cluster operations preserve data:** `make down` stops cluster, `make clean` removes cluster
- **Persistent locations:** `data/kubeconfig/` (cluster config), `data/local-storage/` (volumes)
- **Data safety:** All `make` commands preserve `data/` directory - only manual deletion removes data

## Extensions

**Filesystem-Based:**
```bash
make deploy extension/my-app   # software/apps/extension/my-app/app.yaml
make build src/extension/my-app
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

## Error Recovery Patterns

**When Tasks Fail:**

1. **Triage and Delegation:**
   ```bash
   make status  # Check overall cluster state first
   ```
   - If infrastructure-related (cluster, networking, resources) → delegate to `cluster-agent`
   - If software-related (Flux, apps, GitOps) → delegate to `software-agent`
   - If workflow-related (make commands, coordination) → handle directly

2. **Make Command Errors:**
   ```bash
   make status  # Check cluster state first
   make logs    # Examine recent logs
   ```

3. **GitOps Sync Issues:**
   ```bash
   make sync    # Force reconciliation
   # If sync continues failing → delegate to software-agent
   ```

4. **Debugging Tool Priority:**
   - **First**: Use `make` commands for high-level health checks
   - **Second**: Delegate to appropriate subagent based on problem domain
   - **Third**: Use MCP tools for detailed analysis:
     - `mcp_kubernetes_kubectl_get` → List resources
     - `mcp_kubernetes_kubectl_describe` → Describe resources
     - `mcp_kubernetes_kubectl_logs` → Fetch logs
     - `mcp_flux-operator_get_flux_instance` → Flux status
     - `mcp_flux-operator_reconcile_flux_kustomization` → Force sync
   - **Fallback**: Raw CLI only if Make, subagents, and MCP unavailable
