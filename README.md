# HostK8s - Host-Mode Kubernetes Development Platform

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

A lightweight Kubernetes development platform built on **Kind**. Deploy complete environments instantly using **GitOps** stamps.

## Why HostK8s?

HostK8s addresses common pain points in Kubernetes development:

* **Manual environment setup** - repeatedly configuring the same development stacks.
* **Environment drift** - inconsistent setups across team members and projects.
* **Heavy tooling overhead** - resource-intensive solutions like Docker Desktop or VM-based tools.

By combining Kind's lightweight approach with GitOps environment stamps, HostK8s provides **reproducible, efficient** Kubernetes development workflows.

**Key advantages:**

* **Environment-as-code** – deploy full stacks with GitOps stamps, no more setup scripts.
* **Team consistency** – everyone gets identical environments from the same stamp.
* **Fast startup** – Kind's direct host execution with no VM boot times.
* **Low resource usage** – 4GB RAM typical vs heavier alternatives.
* **Stack agnostic** – works with any language or framework.

## Key Concepts

### GitOps Stamps

Reusable templates that define infrastructure and application deployments as code. Applied via Flux to keep environments version-controlled and consistent.

### Host-Mode Architecture

Uses your host Docker daemon directly — no nested Docker layers. Works seamlessly with standard tools (`kubectl`, `helm`, etc.).

### AI-Assisted Operations (Optional)

HostK8s includes **comprehensive AI assistance** through specialized agents, subagents, automation hooks, and **Model Context Protocol (MCP)** servers to enhance development and operational workflows:

* **Natural Language Operations** – ask questions about cluster health, deployment status, and troubleshooting in plain English.
* **Specialized AI SubAgents** – domain experts for Kubernetes infrastructure, GitOps workflows, and development lifecycle management.
* **Automated Quality Assurance** – intelligent hooks that enforce code standards, validate commits, and trigger GitOps reconciliation.
* **Intelligent Command Shortcuts** – AI-powered slash commands that automate complex workflows, generate configurations, and execute multi-step operations using natural language prompts.

Integrates with popular AI development tools including Claude Code, GitHub Copilot, and other AI assistants.

### Learn More

For a deeper understanding of the platform's design:

* [Architecture Guide](docs/architecture.md)
* [AI Guide](docs/ai-guide.md) – Optional AI capabilities and usage scenarios

---

## Quick Start

### Prerequisites

* **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+
* **2+ CPU cores, 4GB+ RAM** (8GB recommended)
* **Mac, Linux, or Windows WSL2**

### Install Dependencies

```bash
make help      # Display make options
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
| `LOG_LEVEL`       | Logging verbosity (debug, info, warn, error) | `debug`   |
| `CLUSTER_NAME`    | Name of the Kubernetes cluster                | `hostk8s` |
| `K8S_VERSION`     | Kubernetes version to use                     | `latest`  |
| `KIND_CONFIG`     | Kind config preset (minimal, simple, default) | `default` |
| `FLUX_ENABLED`    | Enable GitOps with Flux                       | `false`   |
| `METALLB_ENABLED` | Enable MetalLB for LoadBalancer support       | `false`   |
| `INGRESS_ENABLED` | Enable NGINX Ingress Controller               | `false`   |
| `GITOPS_REPO`     | Git repository URL for Flux sync (if enabled) | *(none)*  |
| `GITOPS_BRANCH`   | Git branch to use for Flux sync               | `main`    |
| `GITOPS_STAMP`    | Stamp to deploy (e.g., `sample`, `osdu-ci`)   | `sample`  |
