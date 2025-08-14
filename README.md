# HostK8s - Host Mode Kubernetes Development Platform

*A lightweight Kubernetes development platform built on **KinD**.*

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Why HostK8s?

HostK8s is designed to let you run what kubernetes services and software components you actually need, wherever you need them. Pick just the building blocks necessary for your task, or bring up an entire software stack. Turn massive, slow deployments into lightweight, fast environments that you can safely break and rebuild without losing your data, while still allowing for the capabilities of a full system.

### The Developer Reality

You're debugging a microservice that connects to a database, it calls two other APIs, and uses a search engine. The full platform includes workflow orchestration, a networking mesh, message queues, identity management, and dozens of other services. You just need to test your one service, but you're forced to boot up 50+ containers you'll never touch.

Current solutions make simple tasks painful:

* **Resource waste** - 26GB RAM, 6 vCPUs and 45-minute waits for services you'll never use
* **Environment chaos** - Juggling multiple IDEs, countless env vars, nothing reproduces twice
* **Fragile infrastructure** - That 200-line bash script broke again and took your data with it
* **Works-on-my-machine syndrome** - Runs fine locally, crashes on your teammate's setup
* **IDE debugging nightmare** - Debuggers struggle to connect through layers of virtualization

### How HostK8s Works Differently

HostK8s eliminates this complexity by letting you pick exactly what you need. Want to test your API against a database and search engine? Deploy just those three services. Need to swap PostgreSQL for MySQL to test compatibility? Change one line in a config and redeploy.

Beyond selective deployment, the platform separates the cluster from the data, so you can experiment fearlessly. Try that risky Helm chart upgrade, test new networking configs in the mesh, or completely rebuild your environment. The databases and persistent storage survive every change. When something breaks (and it will), you're back to working in 2 minutes instead of 2 hours.

Most importantly, HostK8s bridges the gap between your IDE and distributed services. Connect familiar debugging tools directly to services running in Kubernetes. Set breakpoints, inspect variables, and step through code just like you would with local development, but with the full complexity of a production-like environment.

When you inevitably hit complexity walls, you can ask questions like "why didn't that service start?" or "what's wrong with the ingress configuration?" HostK8s includes AI agents that understand your specific setup. Ask natural language questions and get targeted analysis of your deployment, networking issues, or configuration trade-offs without diving into documentation rabbit holes.

## Key Concepts

#### Software Stacks

Pre-configured software stacks (web app + database, microservices + message queue, etc.) that spin up complete development environments. Deployed through declarative configuration that keeps environments version-controlled and consistent across the project.

Built-in extensibility requiring no code changes. Add custom kubernetes configurations, deploy external applications, and configure custom software stacks while leveraging the HostK8s framework.

[Get started with tutorials →](docs/tutorials/README.md)

#### Host Mode Architecture

HostK8s is built on **Kind** (Kubernetes in Docker) - a tool that runs Kubernetes clusters using Docker containers as nodes. Unlike heavy VM-based solutions, HostK8s uses your host Docker daemon directly, eliminating nested Docker layers and VM overhead. This means faster startup, lower resource usage, and seamless integration with standard tools (`make`, `kubectl`, `helm`, etc.).

[Learn more about the architecture →](docs/architecture.md)

#### AI Guided Operations

Natural language cluster management and software troubleshooting through specialized AI agents, prompts and MCP servers.

[Learn how AI can help →](docs/ai-guide.md)


---


## Prerequisites

| Component | Requirement |
|-----------|-------------|
| Hardware | 4+ CPU cores, 16GB+ RAM |
| OS | **Mac**/**Linux** (bash/zsh) or **Windows** ([pwsh](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)) |
| Package Manager | [Homebrew](https://brew.sh) (Mac/Linux) or [Winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (Windows) |
| Containerization | [Docker Desktop](https://docs.docker.com/get-docker/) v24+ |
| Software | [make](https://www.gnu.org/software/make/) |

## Quick Start

Get started in 3 simple steps:

```bash
export FLUX_ENABLED=true        # Windows: $env:FLUX_ENABLED = "true"

make install                    # Install required tools
make start                      # Start a gitops enabled cluster
make up                         # Bring up a simple software stack
```

#### Windows Setup

```bash
winget install ezwinports.make    # Install make
```

---

## Usage Scenarios

HostK8s supports three primary usage patterns, each optimized for different development workflows and requirements.

### 1. Manual Operations

Direct cluster management with manual application deployments.

> *Ideal for iterative development, learning Kubernetes, and testing individual applications.*

**Basic Development:**
```bash
export INGRESS_ENABLED=true     # Windows: $env:INGRESS_ENABLED = "true"

make start                      # Start basic cluster
make deploy                     # Deploy the default app (simple) to the default namespace
make status                     # Check cluster and app status
make clean                      # Complete cleanup
```

**Advanced Development:**
```bash
export INGRESS_ENABLED=true     # Windows: $env:INGRESS_ENABLED = "true"
export METALLB_ENABLED=true     # Windows: $env:METALLB_ENABLED = "true"

make start                      # Start cluster with LoadBalancer and Ingress
make deploy basic               # Deploy a multi-tier app
make status                     # Monitor cluster health
make restart                    # Quick reset of the cluster without app
make stop                       # Stop cluster (preserve data)
```

### 2. Automated Operations

Complete software stack deployments using GitOps automation.

> *Perfect for consistent environments, team collaboration, and production-like setups.*

**Built-in Sample Stack:**
```bash
export INGRESS_ENABLED=true     # Windows: $env:INGRESS_ENABLED = "true"
export FLUX_ENABLED=true        # Windows: $env:FLUX_ENABLED = "true"

make start                      # Start the cluster with Flux
make up sample                  # Deploy complete GitOps environment
make status                     # Monitor GitOps reconciliation
make sync                       # Force Flux reconciliation when needed
```

### 3. Customizations

Custom applications and cluster configurations for specialized requirements.

> *Enables complete customization while leveraging the HostK8s framework.*

**Custom Clusters:**

Duplicate `kind-custom.yaml` to `kind-config.yaml` found in the `infra/kubernetes` directory and customize as needed.

```bash
export METALLB_ENABLED=true     # Windows: $env:METALLB_ENABLED = "true"
export INGRESS_ENABLED=true     # Windows: $env:INGRESS_ENABLED = "true"
make start                      # Uses the modified cluster configuration
```

**Custom Applications:**
```bash
# Add apps to software/apps/your-app-name/

make deploy advanced           # Deploy Helm chart application
make status                    # Verify deployment
```

**Custom Software Stacks:**
```bash
# Create complete stacks in software/stacks/extension/
export GITOPS_REPO=https://github.com/yourorg/custom-stack  # Windows: $env:GITOPS_REPO = "https://github.com/yourorg/custom-stack"

make up extension                 # Deploy complete custom environment
make status                       # Monitor custom stack deployment
```

---

## Configuration

Duplicate `.env.example` to `.env` and customize as needed.

| Variable          | Description                                   | Default   |
| ----------------- | --------------------------------------------- | --------- |
| `LOG_LEVEL`       | Logging verbosity (debug, info, warn, error)  | `debug`   |
| `CLUSTER_NAME`    | Name of the Kubernetes cluster                | `hostk8s` |
| `K8S_VERSION`     | Kubernetes version to use                     | `latest`  |
| `KIND_CONFIG`     | Kind config file (if not set, uses kind-config.yaml or kind-custom.yaml) | *(none)* |
| `PACKAGE_MANAGER` | Package manager preference (brew, native, winget, chocolatey) | `auto` |
| `FLUX_ENABLED`    | Enable GitOps with Flux                       | `false`   |
| `METALLB_ENABLED` | Enable MetalLB for LoadBalancer support       | `false`   |
| `INGRESS_ENABLED` | Enable NGINX Ingress Controller               | `false`   |
| `GITOPS_REPO`     | Git repository URL for Flux sync (if enabled) | *(none)*  |
| `GITOPS_BRANCH`   | Git branch to use for Flux sync               | `main`    |
| `SOFTWARE_STACK`  | Software stack to deploy                      | `sample`  |
| `NAMESPACE`       | Default namespace for app deployments         | `default` |
