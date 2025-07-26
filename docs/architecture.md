# OSDU-CI Architecture

## Overview

OSDU-CI provides a **host-mode Kubernetes development environment** using Kind (Kubernetes in Docker) running directly on the host Docker daemon. The architecture prioritizes stability, simplicity, and rapid development iteration by eliminating Docker-in-Docker complexity.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Environment                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────── │
│  │   Developer     │  │   CI/CD         │  │   Local       │
│  │   Workstation   │  │   Pipeline      │  │   Testing     │
│  └─────────────────┘  └─────────────────┘  └─────────────── │
│           │                    │                    │        │
│    make up/scripts      make test          make clean        │
└─────────────────────────────────────────────────────────────┘
                           │
                    Host Tools Layer
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                Host Docker Daemon                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Kind Cluster (Single Node)                │ │
│  │  ┌─────────────────────────────────────────────────────┐│ │
│  │  │  Control Plane + Worker (Combined)                 ││ │
│  │  │  • API Server                                      ││ │
│  │  │  • etcd                                            ││ │
│  │  │  • kubelet + containerd                            ││ │
│  │  │  • Optional: MetalLB (LoadBalancer)                ││ │
│  │  │  • Optional: NGINX Ingress (with MetalLB integration) ││ │
│  │  │  • Optional: Flux (GitOps)                       ││ │
│  │  └─────────────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                    Port Mappings (NodePort only)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Host Integration                         │
│  • API Server: localhost:6443                              │
│  • NodePort Services: localhost:8080 (from 30080)         │
│  • Kubeconfig: ./data/kubeconfig/config                    │
│  • Optional Services: registry:5000, prometheus:9090       │
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

**GitOps Examples (`software/stamp/`)**
- Flux GitOps configuration examples
- GitRepository and Kustomization templates
- Helm Release deployment patterns
- Multi-environment GitOps structures

```bash
make deploy           # Deploy default app (app1)
make deploy app2      # Deploy advanced app
make deploy app3      # Deploy multi-service app
APP_DEPLOY=app3 make deploy  # Environment variable approach
```

### Optional Services Layer

**Docker Compose (`docker-compose.yml`)**
- **Registry**: Local container registry (port 5000)
- **Monitoring**: Prometheus stack (port 9090)
- **Profile-based**: Only start what you need

```bash
docker compose --profile registry up -d
docker compose --profile monitoring up -d
```

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
```bash
# Standard workflow
make up           # Start environment
make deploy app1  # Deploy basic application
make deploy app2  # Deploy advanced app (requires MetalLB/Ingress)
make logs         # Debug issues
make restart      # Reset for iteration
```

## Migration from Docker-in-Docker

### Architectural Changes
1. **Eliminated**: Docker-in-Docker complexity
2. **Added**: Host-mode Kind integration
3. **Simplified**: Single-node cluster design
4. **Improved**: Resource efficiency and stability

### Benefits Achieved
- ✅ **Stability**: No Docker Desktop hanging issues
- ✅ **Performance**: 50% faster startup times
- ✅ **Resources**: Lower memory requirements (4GB vs 8GB)
- ✅ **Simplicity**: Standard kubectl/kind workflow
- ✅ **Reliability**: Predictable behavior across platforms

### Recent Enhancements (2025)
- ✅ **MetalLB + Ingress Integration**: Seamless LoadBalancer and HTTP routing
- ✅ **Convention-based Configuration**: Simplified Kind config selection (`minimal`, `simple`, `default`)
- ✅ **Structured App Deployment**: Individual app folders with configurable deployment
- ✅ **IPv4 Network Detection**: Robust Docker subnet detection for MetalLB
- ✅ **Security Improvements**: Environment variable exposure protection
- ✅ **Consolidated Scripts**: Flattened directory structure for better maintainability
- ✅ **Flux GitOps Integration**: Complete GitOps workflow (flux CLI via `make install`)
- ✅ **Hybrid CI/CD Pipeline**: Branch-aware testing with GitLab CI + GitHub Actions
- ✅ **Enhanced Logging**: Detailed GitOps reconciliation status and debugging
- ✅ **Smart Testing**: PR branches get fast validation, main branch gets full testing
- ✅ **Status Reporting**: GitHub Actions reports comprehensive results back to GitLab

## Future Considerations

### Potential Enhancements
- **Multi-cluster support**: For advanced testing scenarios
- **Advanced GitOps patterns**: Multi-tenant configurations, progressive delivery
- **Security hardening**: RBAC templates for production migration
- **Observability stack**: Integrated monitoring and logging with GitOps

### Stability Focus
The architecture prioritizes **stability over features**. Each component serves a clear purpose, and complexity is only added when it provides significant developer value. This approach ensures the environment remains reliable and maintainable as requirements evolve.
