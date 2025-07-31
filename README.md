# HostK8s - Host Mode Kubernetes Development Platform

*A lightweight Kubernetes development platform built on **KinD**.*

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Why HostK8s?

HostK8s addresses common pain points in Kubernetes development:

* **Manual environment setup** - repeatedly configuring the same development stacks.
* **Environment drift** - inconsistent setups across team members and projects.
* **Heavy tooling overhead** - resource-intensive solutions like Docker Desktop or VM-based tools.

HostK8s solves these by letting you deploy isolated apps or complete software configurations in seconds using stamps.

### Key advantages:

* **Environment-as-Code** – deploy full stacks with GitOps stamps, no more setup scripts.
* **Team Consistency** – everyone gets identical environments from the same stamp.
* **Fast Startup** – direct host execution with no VM boot times.
* **Low Resource Usage** – 4GB RAM typical vs heavier alternatives.
* **Stack Agnostic** – works with any language or framework.

## Key Concepts

### Host Mode Architecture

Uses your host Docker daemon directly, eliminating nested Docker layers. Works seamlessly with standard tools (`make`, `kubectl`, `helm`, etc.).

### GitOps Stamps

Reusable templates that define software configurations as code. Applied via Flux to keep environments version-controlled and consistent.

### Extensibility Points

Built-in extensibility requiring no code changes. Add custom kubernetes configurations, deploy external applications, and configure external stamps while leveraging the HostK8s framework.

### AI Guided Operations

Natural language cluster management and software troubleshooting through specialized AI agents, prompts and MCP servers.

### Learn More

For a deeper understanding of the platform's design:

* [Architecture Guide](docs/architecture.md)
* [AI Guide](docs/ai-guide.md)

---

## Quick Start

**Get started in 3 steps:**

```bash
git clone https://community.opengroup.org/danielscholl/osdu-ci.git
make install   # Install dependencies (kind, kubectl, helm, flux)
make up sample # Start cluster with GitOps stamp
```

### Prerequisites

* **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+
* **2+ CPU cores, 4GB+ RAM** (8GB recommended)
* **Mac, Linux, or Windows WSL2**

> **Note:** Required tools (kind, kubectl, helm, flux) are installed automatically via `make install`. Run `make prepare` to setup pre-commit hooks and automation for development workflows.

---

## Usage Scenarios

There are two primary ways to use HostK8s, depending on whether you want **manual control** or **automated software configuration**.

### 1. Manual Cluster with Individual App Deployments

Create a basic cluster and deploy applications one at a time using `make deploy`:

```bash
make up                 # Start empty cluster
make deploy sample/app1 # Deploy an app manually
make deploy sample/app2 # Deploy additional apps as needed
make status             # Check cluster and app status
```

This approach is simple and good for **iterative development** or **testing single applications**.

### 2. Automated GitOps managed Environments

Enable Flux (GitOps) in your configuration, then create a cluster pre-configured as a **stamp** (a declarative software configuration):

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
| `LOG_LEVEL`       | Logging verbosity (debug, info, warn, error)  | `debug`   |
| `CLUSTER_NAME`    | Name of the Kubernetes cluster                | `hostk8s` |
| `K8S_VERSION`     | Kubernetes version to use                     | `latest`  |
| `KIND_CONFIG`     | Kind config preset (minimal, simple, default) | `default` |
| `FLUX_ENABLED`    | Enable GitOps with Flux                       | `false`   |
| `METALLB_ENABLED` | Enable MetalLB for LoadBalancer support       | `false`   |
| `INGRESS_ENABLED` | Enable NGINX Ingress Controller               | `false`   |
| `GITOPS_REPO`     | Git repository URL for Flux sync (if enabled) | *(none)*  |
| `GITOPS_BRANCH`   | Git branch to use for Flux sync               | `main`    |
| `GITOPS_STAMP`    | Stamp to deploy                               | `sample`  |
