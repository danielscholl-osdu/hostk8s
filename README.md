# HostK8s - Host-Mode Kubernetes Development Platform [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

A lightweight Kubernetes development platform built on **Kind**, optimized for direct host integration. Quickly deploy complete environments using **GitOps stamps** – ideal for development, testing, and CI/CD workflows without heavy infrastructure.

## Overview

HostK8s addresses common issues in Kubernetes development setups:

* **High overhead** from Docker-in-Docker or VM-based tools.
* **Slow startup** and resource waste during local testing.
* **Instability** from nested container layers.

By running Kind directly on your host and adopting a GitOps-driven environment pattern, HostK8s provides a **stable, low-overhead** workflow for Kubernetes development.

## Benefits at a Glance

* **Fast startup** – no VM boot times.
* **Low resource usage** – 4GB RAM typical.
* **Stable development cycles** – avoids Docker Desktop hangs.
* **Environment-as-code** – deploy full stacks with GitOps stamps.
* **Stack agnostic** – works with any language or framework.

## Key Concepts

### GitOps Stamps

Reusable templates that define infrastructure and application deployments as code. Applied via Flux to keep environments version-controlled and consistent.

### Host-Mode Architecture

Uses your host Docker daemon directly — no nested Docker layers. Works seamlessly with standard tools (`kubectl`, `helm`, etc.).

### Learn More

For a deeper understanding of the platform's design and decisions, see:

* [Architecture Guide](docs/architecture.md)
* [ADR Catalog (Design Decisions)](docs/adr/README.md)

---

## Quick Start

### Prerequisites

* **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+
* **2+ CPU cores, 4GB+ RAM** (8GB recommended)
* **Mac, Linux, or Windows WSL2**

### Install Dependencies

```bash
make install   # Install required dependencies (kind, kubectl, helm, flux)
make prepare   # Setup development environment (pre-commit, yamllint, hooks)
```

---

## Usage Scenarios

There are two primary ways to use HostK8s, depending on whether you want **manual control** or **GitOps-driven environments**.

### 1. Manual Cluster with Individual App Deployments

Create a basic cluster and deploy applications one at a time using `make deploy`:

```bash
make up                 # Start empty cluster
make deploy sample/app1 # Deploy an app manually
make deploy sample/app2 # Deploy additional apps as needed
make status             # Check cluster and app status
```

This approach is simple and good for **iterative development** or **testing single applications**.

### 2. GitOps-Managed Environment with Stamps

Enable Flux (GitOps) in your configuration, then create a cluster pre-configured with a **stamp** (a declarative environment template):

```bash
# Start cluster with a stamp (apps + infra)
export FLUX_ENABLED=true
make up sample
make status             # Check cluster and app status
```

This approach is ideal for **consistent, repeatable environments** and **multi-service setups**.

---

## Configuration

Duplicate `.env.example` to `.env` and customize as needed. The main options are:

| Variable          | Description                                   | Default   |
| ----------------- | --------------------------------------------- | --------- |
| `CLUSTER_NAME`    | Name of the Kubernetes cluster                | `hostk8s` |
| `K8S_VERSION`     | Kubernetes version to use                     | `latest`  |
| `KIND_CONFIG`     | Kind config preset (minimal, simple, default) | `default` |
| `FLUX_ENABLED`    | Enable GitOps with Flux                       | `false`   |
| `METALLB_ENABLED` | Enable MetalLB for LoadBalancer support       | `false`   |
| `INGRESS_ENABLED` | Enable NGINX Ingress Controller               | `false`   |
| `GITOPS_REPO`     | Git repository URL for Flux sync (if enabled) | *(none)*  |
| `GITOPS_BRANCH`   | Git branch to use for Flux sync               | `main`    |
| `GITOPS_STAMP`    | Stamp to deploy (e.g., `sample`, `osdu-ci`)   | `sample`  |

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

Apache License 2.0 – see [LICENSE](LICENSE) for details.
