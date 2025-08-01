# HostK8s Architecture

## Overview

HostK8s provides a **host-mode Kubernetes development platform** using Kind (Kubernetes in Docker) running directly on the host Docker daemon. The architecture prioritizes stability, simplicity, and rapid development iteration by eliminating Docker-in-Docker complexity.

**Key Innovation:** software stack pattern for deploying complete, declarative environments. The platform is application-agnostic - the "sample" stack demonstrates the pattern, while additional stacks can provide domain-specific complete environments.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Environment                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────── │
│  │   Developer     │  │   CI/CD         │  │   Local      | │
│  │   Workstation   │  │   Pipeline      │  │   Testing    | │
│  └─────────────────┘  └─────────────────┘  └─────────────── │
│           │                  │                    │         │
│    make up/scripts       make test            make clean    │
└─────────────────────────────────────────────────────────────┘
                           │
                    Host Tools Layer
                           │
                           ▼
┌───────────────────────────────────────────────────────────-──┐
│                Host Docker Daemon                            │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Kind Cluster (Single Node)                 │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │  Control Plane + Worker (Combined)                  ││ │
│  │  │  • API Server                                       ││ │
│  │  │  • etcd                                             ││ │
│  │  │  • kubelet + containerd                             ││ │
│  │  │  • Optional: MetalLB (LoadBalancer)                 ││ │
│  │  │  • Optional: NGINX Ingress.                         ││ │
│  │  │  • Optional: Flux (GitOps)                          ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────-───┘
                           │
                    Port Mappings (NodePort only)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Host Integration                         │
│  • API Server: localhost:6443                               │
│  • NodePort Services: localhost:8080 (from 30080)           │
│  • Kubeconfig: ./data/kubeconfig/config                     │
│  • Optional Services: registry:5000, prometheus:9090        │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### Host Tools Layer
**Required Dependencies:**
- **Kind**: Cluster creation and management
- **kubectl**: Kubernetes API interaction
- **Helm**: Package management
- **Docker**: Container runtime (Docker Desktop)

**Installation via Make:**
```bash
make install  # Automatic dependency installation on Mac
```

### Infrastructure Layer (`infra/`)

**Kubernetes Configuration (`infra/kubernetes/`)**
- Single-node Kind cluster optimized for development
- Multiple configuration presets: minimal, simple, default, ci
- Extension support via `extension/` directory
- Optional add-on support (MetalLB, NGINX Ingress)

### Automation Layer (`infra/scripts/`)

**Cluster Lifecycle Scripts:**
- `cluster-up.sh`: Primary cluster creation with validation and convention-based Kind config selection
- `cluster-down.sh`: Clean cluster shutdown
- `cluster-restart.sh`: Fast reset for development iteration
- `validate-cluster.sh`: Cluster validation (--simple for basic tests, full mode for comprehensive)

**Development Utilities:**
- `utils.sh`: Essential development utilities (status, logs, port forwarding)

**Component Setup:**
- `setup-metallb.sh`: LoadBalancer configuration with IPv4 subnet detection
- `setup-ingress.sh`: Ingress controller setup with MetalLB integration
- `setup-flux.sh`: GitOps operator setup (requires flux CLI via `make install`)

### Make Interface Layer

**Standard Conventions (`Makefile`)**
- Follows universal Make patterns (`up`, `down`, `test`, `clean`)
- Automatic KUBECONFIG management
- Unified interface for Kind configs and software stacks
- Progressive complexity (simple to advanced)

```bash
make help                    # Show all commands
make up                      # Start basic cluster
make up minimal              # Start with minimal Kind config
make up simple               # Start with simple Kind config
make up default              # Start with default Kind config
make up sample               # Start with sample software stack
make up extension            # Start with extension software stack
make deploy [app]            # Deploy application (supports app selection)
make restart [stack]         # Fast iteration with optional stack
make clean                   # Complete cleanup
```

### Application Layer (`software/`)

**Structured App Deployment (`software/apps/`)**
- **simple/**: Basic sample application (NodePort, simple deployment)
- **multi-tier/**: Advanced multi-service application with database integration
- **registry-demo/**: Container registry demonstration application
- **extension/sample/**: Example of custom extension application
- **Convention-based**: Each app in own folder with `app.yaml` and `README.md`

**Software Stacks (`software/stack/`)**
- **Stack Pattern**: Declarative deployment templates for complete environments
- **Component/Application Separation**: Infrastructure vs application deployment patterns
- **Bootstrap Workflow**: Universal bootstrap kustomization manages all stacks
- **Selective Sync**: Git ignore patterns for efficient synchronization

### Extension System (`extension/`)

**Complete Extensibility Without Code Changes:**
- **Custom Kind Configs**: Add cluster configurations in `infra/kubernetes/extension/`
- **Custom Applications**: Deploy specialized apps via `software/apps/extension/`
- **Custom Software Stacks**: Complete environments in `software/stack/extension/`

**Template Processing for Extensions:**
- **Environment Variable Substitution**: Extension stacks use `envsubst` for dynamic configuration
- **Auto-Detection**: Platform automatically detects and processes extension stacks
- **External Repository Support**: Extensions can reference external Git repositories

**Extension System Architecture:**

```
infra/kubernetes/extension/
├── kind-my-config.yaml          # Custom cluster configuration
└── README.md                    # Extension documentation

software/apps/extension/
├── my-app/
│   ├── app.yaml                 # Application manifests
│   └── README.md               # App documentation
└── README.md                   # Apps extension guide

software/stack/extension/
├── my-stack/
│   ├── kustomization.yaml      # Stack entry point
│   ├── repository.yaml         # GitRepository with ${GITOPS_REPO}
│   ├── stack.yaml             # Component dependencies
│   ├── components/            # Infrastructure Helm releases
│   └── applications/          # Application manifests
└── README.md                  # Stack extension guide
```

**Template Processing Mechanics:**
```yaml
# software/stack/extension/my-stack/repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: external-stack-system
spec:
  url: ${GITOPS_REPO}           # Substituted via envsubst
  ref:
    branch: ${GITOPS_BRANCH}    # Substituted via envsubst
  interval: 1m
```

**Extension Usage Patterns:**
```bash
# Custom cluster configurations
export KIND_CONFIG=extension/my-config
make up                              # Start with custom Kind config

# Custom applications
make deploy extension/my-app         # Deploy extension application

# Custom software stacks with template processing
export GITOPS_REPO=https://github.com/my-org/custom-stack
export GITOPS_BRANCH=develop
make up extension                    # Deploy external software stack
```

```bash
# Manual application deployment
make deploy              # Deploy default app (simple)
make deploy multi-tier   # Deploy advanced multi-service app
make deploy registry-demo # Deploy registry demonstration app

# Software stack deployment
make up sample           # Start cluster with sample stack
make restart sample      # Restart cluster with sample stack
```

### Software Stack Architecture

**Stack Pattern Structure**

```
software/stack/
├── README.md              # Software stacks documentation
├── bootstrap.yaml         # Universal bootstrap kustomization
└── sample/                # Sample stack (GitOps demonstration)
    ├── kustomization.yaml # Stack entry point
    ├── repository.yaml    # GitRepository source definition
    ├── stack.yaml         # Component deployments (infrastructure)
    ├── components/        # Infrastructure components (Helm releases)
    │   ├── database/      # PostgreSQL deployment
    │   └── ingress-nginx/ # NGINX Ingress controller
    └── applications/      # Application deployments (GitOps apps)
        ├── api/           # Sample API service
        └── website/       # Sample website service
```

**Stack Deployment Flow**

```
1. Bootstrap Kustomization (bootstrap.yaml)
   └── Points to specific stack path (e.g., ./software/stack/sample)

2. Stack Kustomization (sample/kustomization.yaml)
   ├── repository.yaml     # Creates GitRepository source
   └── stack.yaml          # Deploys infrastructure components

3. Component Dependencies (stack.yaml)
   ├── component-certs     # Certificate management (cert-manager)
   ├── component-certs-ca  # Root CA certificate
   └── component-certs-issuer # Certificate issuer

4. Infrastructure Helm Releases (components/)
   ├── database/           # PostgreSQL via Helm
   └── ingress-nginx/      # NGINX Ingress via Helm

5. Application Manifests (applications/)
   ├── api/               # GitOps-managed API deployment
   └── website/           # GitOps-managed website deployment
```

### Component Services Layer

**Flux-Managed Components (`software/components/`)**
- **Registry**: Container registry deployed via Flux (available in stacks)
- **Certificate Management**: cert-manager for TLS certificates
- **Ingress**: NGINX Ingress controller for HTTP routing
- **All services**: Declaratively managed through GitOps

## Design Principles

### 1. Host-Mode Stability
- **No Docker-in-Docker**: Eliminates nested container instability
- **Direct Kind usage**: Leverages Kind's native host integration
- **Standard tooling**: Uses host-installed tools as designed

### 2. Ephemeral by Design
- **Disposable clusters**: Create/destroy in under 2 minutes
- **No persistent state**: Everything reproducible from code
- **Fast iteration**: `make restart` for quick resets

### 3. Development-First
- **Single-node simplicity**: No multi-node complexity
- **NodePort access**: Simple, reliable service access
- **Minimal resources**: 4GB RAM sufficient

### 4. Cross-Platform Consistency
- **Identical behavior**: Mac, Windows WSL2, Linux
- **Standard tools**: Same commands everywhere
- **Make interface**: Universal developer experience

### 5. Progressive Complexity
- **Simple by default**: Basic cluster with no add-ons
- **Opt-in features**: Enable MetalLB/Ingress when needed
- **Graceful degradation**: Missing components don't break core functionality

## Network Architecture

```
Host Network (localhost)
├── :6443    → Kubernetes API Server
├── :8080    → NodePort Services (mapped from 30080)
├── :8443    → HTTPS NodePort (mapped from 30443)
├── :5000    → Container Registry (optional)
└── :9090    → Prometheus (optional)

Kind Network (172.18.0.0/16)
└── Single Node: 172.18.0.2
    ├── Control Plane + Worker
    ├── MetalLB Pool: 172.18.255.200-250 (if enabled)
    └── Ingress Controller: Routes HTTP/HTTPS to services
```

## Data Flow

### Development Workflow
1. **Developer** runs `make up`
2. **Make** calls `infra/scripts/cluster-up.sh`
3. **Script** validates dependencies and Docker resources
4. **Kind** creates cluster using convention-based configuration
5. **Kubeconfig** exported to `data/kubeconfig/config`
6. **Make** sets KUBECONFIG automatically for subsequent commands

### Service Access
- **NodePort**: Primary access method via localhost:8080 (mapped from 30080)
- **LoadBalancer**: External IPs (172.18.255.200-250) when MetalLB enabled
- **Ingress**: HTTP routing via NGINX Ingress with MetalLB LoadBalancer integration

## Security Model

### Development Security
- **Host tool access**: Scripts run with user permissions
- **Docker socket**: Read-only access for Kind operations
- **No privileged containers**: Eliminated DinD security risks

### Isolation Boundaries
- **Container-level**: Kind cluster isolated in Docker container
- **Kubernetes namespaces**: Standard pod-to-pod isolation
- **Host filesystem**: Limited volume mounts for kubeconfig only

## Performance Characteristics

### Resource Requirements
- **Minimum**: 4GB RAM, 2 CPU cores
- **Recommended**: 8GB RAM, 4 CPU cores
- **Single-node efficiency**: Lower overhead than multi-node

### Timing Benchmarks
- **Cluster creation**: < 2 minutes on modern hardware (8GB RAM, 4+ CPU cores, SSD storage)
- **Cluster destruction**: < 30 seconds
- **Development reset**: < 1 minute (dev-cycle)
- **Application deployment**: < 30 seconds

## AI-Assisted Operations Integration (Optional)

### MCP Server Architecture

HostK8s optionally integrates **dual MCP servers** to enable comprehensive AI-assisted operations through the Model Context Protocol (MCP). This optional integration bridges AI assistants with both Kubernetes infrastructure and GitOps pipelines for users who choose to enable AI assistance.

**MCP Integration Flow**

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Assistant (Claude)                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │   Natural Language Operations                           ││
│  │   • "Show me cluster status and health"                 ││
│  │   • "Analyze Flux deployment issues"                    ││
│  │   • "Compare resources between clusters"                ││
│  │   • "Debug failing pods and trace dependencies"         ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
                    MCP Protocol
                           │
                           ▼
┌─────────────────┬───────────────────────────────────────────┐
│   Kubernetes    │           Flux Operator                   │
│   MCP Server    │           MCP Server                      │
│  ┌──────────────┴┐ ┌───────────────────────────────────────┐│
│  │ Core K8s Ops  │ │     GitOps Operations                 ││
│  │ • Pod mgmt    │ │     • get_flux_instance               ││
│  │ • Svc access  │ │     • get_kubernetes_resources        ││
│  │ • Logs/events │ │     • search_flux_docs                ││
│  │ • Deployment  │ │     • apply_kubernetes_resource       ││
│  └───────────────┘ └───────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
                    KUBECONFIG Auth
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              HostK8s Kubernetes Cluster                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │   Complete Kubernetes & GitOps Resources                ││
│  │   • Pods, Services, Deployments                         ││
│  │   • FluxInstance, ResourceSets                          ││
│  │   • GitRepository, Kustomizations                       ││
│  │   • HelmRelease, OCIRepository                          ││
│  │   • Application Deployments                             ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

**Key Features**

- **Comprehensive Kubernetes Operations**: Natural language queries for cluster management, pod troubleshooting, and resource analysis
- **Advanced GitOps Operations**: AI-powered Flux resource management, dependency visualization, and deployment debugging
- **Root Cause Analysis**: Automated investigation of failed deployments with cross-resource dependency tracing
- **Cross-Cluster Management**: Compare configurations and resources between different environments using either MCP server
- **Documentation Integration**: Search and reference latest Flux documentation during operations
- **Visual Diagrams**: Generate Mermaid diagrams showing both infrastructure and GitOps dependencies

### MCP Server Configuration

Both MCP servers are configured for multiple AI assistants:

**Claude Code** (`.mcp.json`)
**GitHub Copilot** (`.vscode/mcp.json`)

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "npx",
      "args": ["mcp-server-kubernetes"],
      "env": {
        "KUBECONFIG_PATH": "./data/kubeconfig/config"
      }
    },
    "flux-operator-mcp": {
      "command": "flux-operator-mcp",
      "args": ["serve"],
      "env": {
        "KUBECONFIG": "./data/kubeconfig/config"
      }
    }
  }
}
```

**Server Responsibilities**
- **Kubernetes MCP Server**: Core Kubernetes operations (pods, services, deployments, logs, events)
- **Flux Operator MCP Server**: GitOps operations (Flux resources, documentation search, dependency analysis)

**Security Model**
- Uses existing KUBECONFIG permissions (same as `kubectl` access)
- Supports read-only mode via `FLUX_MCP_READ_ONLY=true`
- Automatically masks sensitive data in Kubernetes Secrets
- No additional cluster permissions required



## Integration Points

### Hybrid CI/CD Integration

**GitLab CI (Fast Track)**
```yaml
# GitLab CI pipeline
stages:
  - validate    # YAML, Makefile validation (2-3 min)
  - deploy      # GitHub sync and branch management
  - test        # Smart GitHub Actions triggering
```

**GitHub Actions (Comprehensive Track)**
```yaml
# Branch-aware cluster testing with CI-specific configuration
strategy:
  matrix:
    cluster_type: [minimal, default]
jobs:
  cluster-minimal:    # Always runs (GitRepository validation)
  cluster-default:    # Main branch only (full GitOps)
```

**CI Configuration Support**
- **Special `ci` Kind config**: Optimized for GitLab CI with Docker-in-Docker networking
- **Automatic kubeconfig fixes**: Replaces localhost with docker hostname for CI environments
- **Resource-optimized**: Minimal resource allocation for CI pipelines

**Integration Flow**
1. **GitLab CI**: Fast validation + GitHub sync using `ci` config
2. **GitHub Actions**: Branch-aware comprehensive testing
3. **Status Reporting**: Results reported back to GitLab

### IDE Integration
```bash
# Automatic kubectl context
export KUBECONFIG=$(pwd)/data/kubeconfig/config
kubectl get pods
```

### Local Development

**Manual App Deployment:**
```bash
make up                 # Start basic cluster
make deploy simple      # Deploy basic application
make deploy multi-tier  # Deploy multi-service app (requires MetalLB/Ingress)
make logs               # Debug issues
make restart            # Reset for iteration
```

**GitOps Stack Deployment:**
```bash
make up sample          # Start cluster with sample GitOps stack
make status             # Monitor GitOps reconciliation
make sync               # Force Flux reconciliation
flux get all            # Check Flux resources
flux logs --follow      # Watch GitOps sync logs
make restart sample     # Reset with stack configuration
```


---

## Architecture Decision Records

For detailed rationale behind key design choices, see our Architecture Decision Records:

### ADR Index

| id  | title                               | status | details |
| --- | ----------------------------------- | ------ | ------- |
| 001 | Host-Mode Architecture              | acc    | [ADR-001](adr/001-host-mode-architecture.md) |
| 002 | Make Interface Standardization     | acc    | [ADR-002](adr/002-make-interface-standardization.md) |
| 003 | GitOps Stamp Pattern               | acc    | [ADR-003](adr/003-gitops-stamp-pattern.md) |
| 004 | Hybrid CI/CD Strategy              | acc    | [ADR-004](adr/004-hybrid-ci-cd-strategy.md) |

### ADR Summaries

**ADR-001: Host-Mode Architecture**
- **Decision**: Use Kind directly on host Docker daemon, eliminating Docker-in-Docker complexity
- **Benefits**: Stability, 50% faster startup, lower resource usage (4GB vs 8GB), standard kubectl/kind workflow
- **Tradeoffs**: Less isolation, Docker Desktop dependency, single-node limitation

**ADR-002: Make Interface Standardization**
- **Decision**: Implement standardized Make interface wrapping all operational scripts with consistent conventions
- **Benefits**: Universal familiarity, standard conventions, automatic KUBECONFIG handling, discoverability
- **Tradeoffs**: Abstraction layer, Make dependency, argument limitations

**ADR-003: GitOps Stamp Pattern**
- **Decision**: Implement stamp pattern for deploying complete environments via Flux with component/application separation
- **Benefits**: Complete environments, platform agnostic, dependency management, reusability
- **Tradeoffs**: Learning curve, debugging complexity, bootstrap dependency

**ADR-004: Hybrid CI/CD Strategy**
- **Decision**: Branch-aware hybrid CI/CD combining GitLab CI (fast) with GitHub Actions (comprehensive)
- **Benefits**: Fast feedback (2-3 min), comprehensive testing (8-10 min), branch-aware optimization
- **Tradeoffs**: Dual platform complexity, sync overhead

Each ADR documents the context, decision, alternatives considered, and consequences - providing the "why" behind HostK8s's unique architecture.

---

## Navigation

- **← [Back to README](../README.md)** - Getting started guide
- **→ [AI-Assisted Development](ai-assisted-development.md)** - Optional AI capabilities and usage scenarios
- **→ [ADR Catalog](adr/README.md)** - All architecture decisions
- **→ [Sample Apps](../software/apps/README.md)** - Available applications
