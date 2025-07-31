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

HostK8s supports three primary usage patterns, each optimized for different development workflows and requirements.

### 1. Manual Operations

Direct cluster management with manual application deployments. Ideal for **iterative development**, **learning Kubernetes**, and **testing individual applications**.

**Basic Development:**
```bash
make up                 # Start basic cluster
make deploy             # Deploy default app (simple)
make deploy multi-tier  # Deploy advanced multi-service app
make status             # Check cluster and app status
make restart            # Quick reset for development iteration
make clean              # Complete cleanup
```

**Advanced Development with Infrastructure:**
```bash
export INGRESS_ENABLED=true
export METALLB_ENABLED=true
make up                 # Start cluster with LoadBalancer and Ingress
make deploy multi-tier  # Deploy apps requiring advanced networking
make status             # Monitor cluster health
```

### 2. Automated GitOps

Complete software stack deployments using GitOps automation. Perfect for **consistent environments**, **team collaboration**, and **production-like setups**.

**Built-in Sample Stack:**
```bash
make up sample          # Deploy complete GitOps environment
make status             # Monitor GitOps reconciliation
make sync               # Force Flux reconciliation when needed
```

**External GitOps Repository:**
```bash
export GITOPS_REPO=https://github.com/yourorg/your-stack-repo
export GITOPS_BRANCH=main
make up extension       # Deploy from external repository
make status             # Monitor deployment progress
```

### 3. Extensions

Custom applications and cluster configurations for specialized requirements. Enables **complete customization** while leveraging the HostK8s framework.

**Custom Applications:**
```bash
# Add apps to software/apps/extension/your-app-name/
export METALLB_ENABLED=true
export INGRESS_ENABLED=true
make up                      # Start with required infrastructure
make deploy extension/sample # Deploy custom application
make status                  # Verify deployment
```

**Custom Cluster Configurations:**
```bash
# Add configs to infra/kubernetes/extension/kind-your-name.yaml
export KIND_CONFIG=extension/sample
export FLUX_ENABLED=false
make up                           # Start with custom cluster config
make deploy extension/sample      # Deploy matching application
make status                       # Check customized environment
```

**Custom Software Stacks:**
```bash
# Create complete stacks in software/stack/extension/
export GITOPS_REPO=https://github.com/yourorg/custom-stack
make up extension                 # Deploy complete custom environment
make status                       # Monitor custom stack deployment
```

> **Note**: Extensions require no code changes to HostK8s core - simply add files in the appropriate `extension/` directories with proper labels and configurations.

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
| `SOFTWARE_STACK`  | Software stack to deploy                      | `sample`  |
