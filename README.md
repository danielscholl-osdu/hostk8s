# HostK8s - Host-Mode Kubernetes Development Platform

A lightweight, stable Kubernetes development platform using **Kind** directly on your host. Deploy complete environments via GitOps stamps - perfect for rapid development, testing, and CI/CD pipelines without heavy infrastructure.

## Why HostK8s?

**The Problem:** Traditional Kubernetes development environments suffer from Docker-in-Docker complexity, resource overhead, and stability issues.

**The Solution:** HostK8s uses a **host-mode architecture** with **GitOps stamps** to provide:
- ✅ **50% faster startup** compared to virtualized solutions
- ✅ **Lower resource usage** (4GB vs 8GB typical)
- ✅ **Rock-solid stability** - eliminates Docker Desktop hanging issues
- ✅ **Complete environments** - infrastructure + applications deployed together
- ✅ **Platform-agnostic** - works with any software stack via stamps

## Key Concepts

### GitOps Stamps
**Stamps** are declarative templates that deploy complete environments (infrastructure + applications) via Flux GitOps. Think "environment-as-code" - consistent, reusable, version-controlled.

```bash
make up sample    # Deploy complete sample environment with DB, ingress, apps
make up osdu-ci   # (Future) Deploy complete OSDU platform environment
```

### Host-Mode Architecture
Run Kind directly on your host Docker daemon instead of nested containers. Standard kubectl/helm tools work seamlessly.

---

## Quick Start

### Prerequisites
- **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+
- **2+ CPU cores, 4GB+ RAM** (8GB recommended)
- **Mac, Linux, or Windows WSL2**

### Install Dependencies
```bash
make install   # Installs kind, kubectl, helm, flux via your package manager
```

### Basic Usage
```bash
# Start basic cluster
make up
make deploy sample/app1
make status

# Deploy complete GitOps environment
make up sample
make status       # Shows GitOps reconciliation status
flux get all      # Monitor Flux resources

# Development iteration
make restart      # Quick reset
make clean        # Complete cleanup
```

### Configuration
Copy `.env.example` to `.env` and customize:
```bash
CLUSTER_NAME=hostk8s
METALLB_ENABLED=true    # LoadBalancer support
INGRESS_ENABLED=true    # HTTP routing
FLUX_ENABLED=true       # GitOps capabilities
```

---

## Available Applications

### Manual Deployment
```bash
make deploy sample/app1    # Basic NodePort app
make deploy sample/app2    # Advanced app (MetalLB + Ingress)
make deploy sample/app3    # Multi-service microservices demo
```

### GitOps Stamps
```bash
make up sample            # Sample stamp: demo apps + infrastructure
# make up osdu-ci         # (Future) OSDU Community Implementation
```

---

## Common Commands

```bash
# Cluster Management
make up [stamp]     # Start cluster (optionally with GitOps stamp)
make status         # Health check and service access info
make restart        # Quick development reset
make down           # Stop cluster (preserve data)
make clean          # Complete cleanup

# Development
make deploy <app>   # Deploy specific application
make logs           # View recent cluster events
make test           # Run validation tests
make sync           # Force GitOps reconciliation

# Debugging
kubectl run debug --image=busybox --rm -it --restart=Never -- sh
```

---

## Troubleshooting

**Common Issues:**
- **Port conflicts** → Check with `netstat -tulpn`
- **Slow startup** → Pre-pull image: `docker pull kindest/node:v1.33.1`
- **Memory issues** → Increase Docker Desktop memory allocation

**Diagnostics:**
```bash
make status    # Comprehensive health check
make logs      # Recent cluster events
flux get all   # GitOps status (if using stamps)
```

---

## Documentation

### 📖 Learn More
- **[Architecture Guide](docs/architecture.md)** - Deep dive into design decisions and implementation
- **[ADR Catalog](docs/adr/README.md)** - Architecture Decision Records explaining key choices
- **[Sample Apps](software/apps/README.md)** - Available applications and deployment patterns
- **[GitOps Stamps](software/stamp/README.md)** - Creating and using environment stamps

### 🏗️ Key Design Decisions
- **[ADR-001: Host-Mode Architecture](docs/adr/001-host-mode-architecture.md)** - Why eliminate Docker-in-Docker
- **[ADR-002: Kind Technology Selection](docs/adr/002-kind-technology-selection.md)** - Why Kind over alternatives
- **[ADR-004: GitOps Stamp Pattern](docs/adr/004-gitops-stamp-pattern.md)** - Complete environment deployment innovation

### 🔧 Development
- **[Contributing](CONTRIBUTING.md)** - How to contribute to HostK8s
- **[CI/CD Strategy](docs/adr/005-hybrid-ci-cd-strategy.md)** - Branch-aware testing approach

---

## License

MIT License - see [LICENSE](LICENSE) for details.
