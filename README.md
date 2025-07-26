# OSDU-CI: Host-Mode Kubernetes Development Environment

A lightweight Kubernetes development setup using **Kind** directly on your host. Perfect for rapid development, testing, and CI/CD pipelines without heavy infrastructure.

## Overview

* **Single-node Kind cluster** optimized for development
* Works on **Mac, Linux, and Windows (WSL2)**
* Quick startup with simple deployment and hassle‑free cleanup

---

## Prerequisites

### Hardware Requirements

* **CPU**: 2+ cores (4 recommended)
* **Memory**: 4GB+ (8GB recommended)

### Software Requirements

* **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+ (or [Docker Engine](https://docs.docker.com/engine/install/))
* **[Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)** v0.25+
* **[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)** v1.33+
* **[Helm](https://helm.sh/docs/intro/install/)** v3+

> **Note:** We assume these tools are already installed. Click the links above for official installation guides.

---

## Quick Start (Using Make)

```bash
make prepare   # Setup development environment (pre-commit, yamllint)
make up        # Install dependencies + start cluster
make deploy    # Deploy default app (app1)
make status    # Check cluster health
```

**Common development commands:**

```bash
make restart   # Quick reset during development
make test      # Run validation tests
make clean     # Full cleanup
```

---

## Project Structure (Key Directories)

```
osdu-ci/
├── infra/           # Infrastructure (scripts + k8s configs)
├── software/        # Sample apps and configs
├── data/            # Auto-generated kubeconfig & data
├── docs/            # Detailed documentation
└── .env.example     # Config template
```

---

## Configuration

Edit `.env` to customize:

```bash
CLUSTER_NAME=osdu-ci
K8S_VERSION=v1.33.1
METALLB_ENABLED=true
INGRESS_ENABLED=true
FLUX_ENABLED=true
APP_DEPLOY=app1  # Options: app1 (basic), app2 (advanced)
```

---

## Usage Examples

Start and deploy:

```bash
make up
make deploy        # Deploy default app (app1)
make deploy app2   # Deploy advanced app with MetalLB/Ingress
make status
```

Reset cluster:

```bash
make restart
```

Stop or clean up:

```bash
make down    # Stop but preserve data
make clean   # Full cleanup
```

Manual debugging:

```bash
kubectl run debug --image=busybox --rm -it --restart=Never -- sh
```

---

## CI/CD Integration

OSDU-CI uses a **branch-aware hybrid testing strategy** for optimal development velocity:

### 🚀 Fast Track (GitLab CI) - Always Runs
- **Duration**: 2-3 minutes
- **Purpose**: Quick feedback and GitHub sync
- **Tests**: Project structure, Makefile interface, YAML validation
- **Smart**: Only triggers GitHub Actions for core file changes

### 🔍 Comprehensive Track (GitHub Actions) - Branch Aware

#### PR Branches (Fast Validation)
- **Duration**: ~5 minutes
- **Focus**: cluster-minimal only (Flux + GitRepository validation)
- **Purpose**: Quick PR feedback without full GitOps overhead

#### Main Branch (Full Validation)
- **Duration**: ~8-10 minutes
- **Focus**: cluster-minimal + cluster-default (full GitOps testing)
- **Purpose**: Complete validation with Kustomizations and applications

### Enhanced Logging
Both testing tracks now include detailed logging to show exactly what's being tested:
- **cluster-minimal**: Clearly states "GitRepository source validation only"
- **cluster-default**: Shows Kustomization application and GitOps reconciliation details

See [docs/HYBRID-CI.md](docs/HYBRID-CI.md) for detailed setup and configuration.

---

## Troubleshooting

**Common fixes:**

* Port conflicts → Check with `netstat -tulpn`
* Slow startup → Pre-pull node image: `docker pull kindest/node:v1.33.1`
* Memory issues → Increase Docker memory allocation

Diagnostics:

```bash
make status   # Cluster health
make logs     # Recent events
kubectl get pods -A
```

---

## Next Steps

* Explore [software/](software/) for sample apps and GitOps examples
* Try GitOps: `FLUX_ENABLED=true make up` then see [software/stamp/](software/stamp/)
* Read [docs/architecture.md](docs/architecture.md) for detailed design
* File issues or contribute via GitHub pull requests

---

## Advanced Features

### Branch-Aware Testing
- **PR branches**: Fast GitRepository source validation (~5 min)
- **Main branch**: Full GitOps testing with Kustomizations (~8-10 min)
- **Smart triggering**: Only tests when core files change
- **Enhanced logging**: Clear visibility into what's being tested

### GitOps Integration
```bash
# Enable GitOps and test full workflow
FLUX_ENABLED=true make up
kubectl apply -f software/stamp/sources/
kubectl apply -f software/stamp/clusters/osdu-ci/
flux get all
```

### Multi-App Deployment
```bash
make deploy app1  # Basic NodePort app
make deploy app2  # Advanced app with MetalLB + Ingress
make deploy app3  # Multi-service microservices demo
```
