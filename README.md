# HostK8s - Host Mode Kubernetes Development Platform

*A lightweight Kubernetes development platform built on **KinD**.*

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Why HostK8s?

HostK8s addresses common pain points in Kubernetes development:

* **Manual environment setup** - repeatedly configuring the same development stacks.
* **Environment drift** - inconsistent setups across team members and projects.
* **Heavy tooling overhead** - resource-intensive solutions that reserve dedicated host resources or require VM layers.

HostK8s solves these by letting you deploy isolated apps or complete software stacks in seconds using predefined configurations.

### Key advantages:

* **Environment-as-Code** – deploy complete software stacks with GitOps, no more setup scripts.
* **Team Consistency** – everyone gets identical environments from the same stack configuration.
* **Fast Startup** – direct host execution with no VM boot times.
* **Low Resource Usage** – 4GB RAM typical vs heavier alternatives.
* **Stack Agnostic** – works with any language or framework.

## Key Concepts

### Host Mode Architecture

Uses your host Docker daemon directly, eliminating nested Docker layers. Works seamlessly with standard tools (`make`, `kubectl`, `helm`, etc.).

### Software Stacks

Pre-configured software stacks (web app + database, microservices, etc.) that spin up complete development environments. Applied via GitOps to keep environments version-controlled and consistent.

### Extensibility Points

Built-in extensibility requiring no code changes. Add custom kubernetes configurations, deploy external applications, and configure custom software stacks while leveraging the HostK8s framework.

### AI Guided Operations

Natural language cluster management and software troubleshooting through specialized AI agents, prompts and MCP servers.

### Learn More

For a deeper understanding of the platform's design:

* [Architecture Guide](docs/architecture.md)
* [AI Guide](docs/ai-guide.md)

---

## Quick Start

**Get started in 2 steps:**

```bash
git clone https://community.opengroup.org/danielscholl/hostk8s.git
make up sample # Start cluster with software stack
```

### Prerequisites

* **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+
* **2+ CPU cores, 4GB+ RAM** (8GB recommended)
* **Mac, Linux, or Windows WSL2**

> **Note:** Required tools (kind, kubectl, helm, flux) are installed automatically via `make install`. Run `make prepare` to setup pre-commit hooks and automation for development workflows.

---

## Usage Scenarios

There are two primary ways to use HostK8s, depending on whether you want **individual app control** or **complete software stacks**.

### 1. Manual Cluster with Individual App Deployments

Create a basic cluster and deploy applications one at a time using `make deploy`:

```bash
export FLUX_ENABLED=false
export INGRESS_ENABLED=true
make up                 # Start empty cluster
make deploy             # Deploy default app (simple)
make deploy multi-tier  # Deploy advanced multi-service app
make status             # Check cluster and app status
make down               # Stop cluster (preserves data)
make restart            # Quick reset for development iteration
make clean              # Complete cleanup (destroy cluster and data)
```

**Extension Apps**: Add custom applications by placing them in `software/apps/extension/your-app-name/` with an `app.yaml` file and proper `hostk8s.app` labels. Most extension apps require additional infrastructure:

```bash
export FLUX_ENABLED=false
export METALLB_ENABLED=true
export INGRESS_ENABLED=true
make up                      # Start cluster with LoadBalancer and Ingress support
make deploy extension/sample # Deploy extension apps
make status                  # Check cluster and app status
make clean                   # Complete cleanup when done
```

**Custom Cluster + Custom App**: Combine custom Kubernetes configurations with custom applications for complete extensibility:

```bash
# Use custom cluster configuration with custom app
export FLUX_ENABLED=false
export METALLB_ENABLED=true
export INGRESS_ENABLED=true
export KIND_CONFIG=extension/sample
make up                           # Start with custom cluster config
make deploy extension/sample      # Deploy custom app  
make status                       # Check status
make clean                        # Complete cleanup
```

Add custom cluster configurations as `infra/kubernetes/extension/kind-your-name.yaml` to customize networking, storage, or other cluster features.

This approach is simple and good for **iterative development** or **testing single applications**.

### 2. Complete Software Stack Deployments

Enable GitOps to deploy complete software stacks - pre-configured environments with multiple services working together:

```bash
# Start cluster with complete software stack
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
| `LOG_LEVEL`       | Logging verbosity (debug, info, warn, error)  | `debug`   |
| `CLUSTER_NAME`    | Name of the Kubernetes cluster                | `hostk8s` |
| `K8S_VERSION`     | Kubernetes version to use                     | `latest`  |
| `KIND_CONFIG`     | Kind config preset (minimal, simple, default) | `default` |
| `PACKAGE_MANAGER` | Package manager preference (brew, native)     | `auto`    |
| `FLUX_ENABLED`    | Enable GitOps with Flux                       | `false`   |
| `METALLB_ENABLED` | Enable MetalLB for LoadBalancer support       | `false`   |
| `INGRESS_ENABLED` | Enable NGINX Ingress Controller               | `false`   |
| `GITOPS_REPO`     | Git repository URL for Flux sync (if enabled) | *(none)*  |
| `GITOPS_BRANCH`   | Git branch to use for Flux sync               | `main`    |
| `GITOPS_STACK`    | Software stack to deploy                      | `sample`  |
