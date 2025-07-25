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

OSDU-CI uses a **hybrid testing strategy** for optimal development velocity:

### 🚀 Fast Track (GitLab CI)
- **Duration**: 2-3 minutes
- **Purpose**: Quick feedback during development
- **Tests**: Project structure, Makefile interface, tool installation

### 🔍 Comprehensive Track (GitHub Actions) 
- **Duration**: 5-10 minutes  
- **Purpose**: Full Kubernetes and GitOps validation
- **Tests**: Complete cluster creation, application deployment, connectivity

### How it works:
1. Push code → GitLab CI runs fast validation
2. On success → Automatically triggers GitHub Actions
3. GitHub Actions runs comprehensive Kubernetes testing

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