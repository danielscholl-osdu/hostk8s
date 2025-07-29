# HostK8s Architecture

## Overview

HostK8s provides a **host-mode Kubernetes development platform** using Kind (Kubernetes in Docker) running directly on the host Docker daemon. The architecture prioritizes stability, simplicity, and rapid development iteration by eliminating Docker-in-Docker complexity.

**Key Innovation:** GitOps stamp pattern for deploying complete, declarative environments. The platform is application-agnostic - the "sample" stamp demonstrates the pattern, while future stamps (like OSDU-CI) will provide domain-specific complete environments.

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
- Balanced resource allocation (not over-optimized)
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
- Progressive complexity (simple to advanced)

```bash
make help        # Show all commands
make up          # Start cluster
make deploy      # Deploy application (supports app selection)
make restart     # Fast iteration
make clean       # Complete cleanup
```

### Application Layer (`software/`)

**Structured App Deployment (`software/apps/`)**
- **app1/**: Basic sample application (NodePort, 2 replicas)
- **app2/**: Advanced sample with MetalLB + Ingress (3 replicas, multiple services)
- **app3/**: Multi-service microservices (Frontend → API → Database, 5 replicas)
- **Convention-based**: Each app in own folder with `app.yaml` and `README.md`

**GitOps Stamps (`software/stamp/`)**
- **Stamp Pattern**: Declarative deployment templates for complete environments
- **Component/Application Separation**: Infrastructure vs application deployment patterns
- **Bootstrap Workflow**: Universal bootstrap kustomization manages all stamps
- **Selective Sync**: Git ignore patterns for efficient synchronization

```bash
# Manual application deployment
make deploy           # Deploy default app (sample/app1)
make deploy sample/app2      # Deploy advanced app
make deploy sample/app3      # Deploy multi-service app

# GitOps stamp deployment
make up sample        # Start cluster with sample stamp
make restart sample   # Restart cluster with sample stamp
```

### GitOps Stamp Architecture

**Stamp Pattern Structure**

```
software/stamp/
├── README.md              # GitOps stamps documentation
├── bootstrap.yaml         # Universal bootstrap kustomization
└── sample/                # Sample stamp (GitOps demonstration)
    ├── kustomization.yaml # Stamp entry point
    ├── repository.yaml    # GitRepository source definition
    ├── stamp.yaml         # Component deployments (infrastructure)
    ├── components/        # Infrastructure components (Helm releases)
    │   ├── database/      # PostgreSQL deployment
    │   └── ingress-nginx/ # NGINX Ingress controller
    └── applications/      # Application deployments (GitOps apps)
        ├── api/           # Sample API service
        └── website/       # Sample website service
```

**Stamp Deployment Flow**

```
1. Bootstrap Kustomization (bootstrap.yaml)
   └── Points to specific stamp path (e.g., ./software/stamp/sample)

2. Stamp Kustomization (sample/kustomization.yaml)
   ├── repository.yaml     # Creates GitRepository source
   └── stamp.yaml          # Deploys infrastructure components

3. Component Dependencies (stamp.yaml)
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
- **Registry**: Container registry deployed via Flux (available in stamps)
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
- **Cluster creation**: < 2 minutes on modern hardware
- **Cluster destruction**: < 30 seconds
- **Development reset**: < 1 minute (dev-cycle)
- **Application deployment**: < 30 seconds

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
# Branch-aware cluster testing
strategy:
  matrix:
    cluster_type: [minimal, default]
jobs:
  cluster-minimal:    # Always runs (GitRepository validation)
  cluster-default:    # Main branch only (full GitOps)
```

**Integration Flow**
1. **GitLab CI**: Fast validation + GitHub sync
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
make up           # Start basic cluster
make deploy sample/app1  # Deploy basic application
make deploy sample/app2  # Deploy advanced app (requires MetalLB/Ingress)
make logs         # Debug issues
make restart      # Reset for iteration
```

**GitOps Stamp Deployment:**
```bash
make up sample    # Start cluster with sample GitOps stamp
make status       # Monitor GitOps reconciliation
make sync         # Force Flux reconciliation
flux get all      # Check Flux resources
flux logs --follow # Watch GitOps sync logs
make restart sample # Reset with stamp configuration
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
- **→ [ADR Catalog](adr/README.md)** - All architecture decisions
- **→ [Sample Apps](../software/apps/README.md)** - Available applications
