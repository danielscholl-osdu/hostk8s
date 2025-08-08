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

Beyond selective deployment, the platform separates the cluster from the data, so you can experiment fearlessly. Try that risky Helm chart upgrade, test new networking configs in the mesh, or completely rebuild your environment - the databases and persistent storage survive every change. When something breaks (and it will), you're back to working in 2 minutes, not 2 hours.

Most importantly, HostK8s bridges the gap between your IDE and distributed services. Connect familiar debugging tools directly to services running in Kubernetes. Set breakpoints, inspect variables, and step through code just like you would with local development - but with the full complexity of a production-like environment.

When you inevitably hit complexity walls - why didn't that service start? What's wrong with the ingress configuration? - HostK8s includes AI agents that understand your specific setup. Ask natural language questions and get targeted analysis of your deployment, networking issues, or configuration trade-offs without diving into documentation rabbit holes.

### What This Means for You

* **Quicker environment startup** instead of 45-minute waits
* **Less RAM and Compute usage** instead of burning through 64GB+
* **Configuration you can version control** instead of fragile scripts that break
* **Safe experimentation** - keep your data when you rebuild your environment
* **Real Kubernetes** - test with service mesh, ingress controllers, and enterprise auth patterns
* **Your IDE, your way** - debug distributed services with the tools you already know

## Key Concepts

### Software Stacks

Pre-configured software stacks (web app + database, microservices + message queue, etc.) that spin up complete development environments. Deployed through declarative configuration that keeps environments version-controlled and consistent across the project.

### Host Mode Architecture

HostK8s is built on **Kind** (Kubernetes in Docker) - a tool that runs Kubernetes clusters using Docker containers as nodes. Unlike heavy VM-based solutions, HostK8s uses your host Docker daemon directly, eliminating nested Docker layers and VM overhead. This means faster startup, lower resource usage, and seamless integration with standard tools (`make`, `kubectl`, `helm`, etc.).

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
make up sample # Start cluster with a sample software stack
```

### Prerequisites

* **[Docker Desktop](https://docs.docker.com/get-docker/)** v24+
* **2+ CPU cores, 4GB+ RAM** (8GB recommended)
* **Mac, Linux, or WSL2**

> **Note:** Required tools (kind, kubectl, helm, flux) are installed automatically via `make install`.

---

## Usage Scenarios

HostK8s supports three primary usage patterns, each optimized for different development workflows and requirements.

### 1. Manual Operations

Direct cluster management with manual application deployments. Ideal for **iterative development**, **learning Kubernetes**, and **testing individual applications**.

**Basic Development:**
```bash
export INGRESS_ENABLED=true
make start              # Start basic cluster
make deploy simple      # Deploy to default namespace
make status             # Check cluster and app status
make clean              # Complete cleanup
```

**Advanced Development:**
```bash
export INGRESS_ENABLED=true
make start              # Start cluster with LoadBalancer and Ingress
make deploy complex     # Deploy complex multi-service app
make status             # Monitor cluster health
make restart            # Quick reset for development iteration
make stop               # Stop cluster (preserve data)
```

### 2. Automated Operations

Complete software stack deployments using GitOps automation. Perfect for **consistent environments**, **team collaboration**, and **production-like setups**.

**Built-in Sample Stack:**
```bash
export FLUX_ENABLED=true
make up sample          # Deploy complete GitOps environment
make status             # Monitor GitOps reconciliation
make sync               # Force Flux reconciliation when needed
```

### 3. Custom Extensions

Custom applications and cluster configurations for specialized requirements. Enables **complete customization** while leveraging the HostK8s framework.

**Custom Clusters:**
```bash
# Option 1: Create kind-config.yaml for persistent custom config
cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml
# Edit kind-config.yaml as needed
make start                        # Uses your kind-config.yaml

# Option 2: Use environment variable for temporary config
KIND_CONFIG=kind-custom.yaml make start   # Use example config
KIND_CONFIG=extension/sample make start   # Use extension config
make deploy simple                # Deploy to default namespace
make deploy simple testing           # Deploy to testing namespace
NAMESPACE=apps make deploy simple    # Deploy to apps namespace
make status                       # Check customized environment
```

**Custom Applications:**
```bash
# Add apps to software/apps/your-app-name/
export METALLB_ENABLED=true
export INGRESS_ENABLED=true
make start                   # Start with required infrastructure
make deploy helm-sample       # Deploy Helm chart application
make status                  # Verify deployment
```

**Custom Software Stacks:**
```bash
# Create complete stacks in software/stack/extension/
export GITOPS_REPO=https://github.com/yourorg/custom-stack
make up extension/my-stack        # Deploy complete custom environment
make status                       # Monitor custom stack deployment
```

> **Note**: Extensions require no code changes to HostK8s core - simply add files in the appropriate `extension/` directories with proper labels and configurations or just clone a repo directly.

---

## Configuration

Duplicate `.env.example` to `.env` and customize as needed. The main options are:

| Variable          | Description                                   | Default   |
| ----------------- | --------------------------------------------- | --------- |
| `LOG_LEVEL`       | Logging verbosity (debug, info, warn, error)  | `debug`   |
| `CLUSTER_NAME`    | Name of the Kubernetes cluster                | `hostk8s` |
| `K8S_VERSION`     | Kubernetes version to use                     | `latest`  |
| `KIND_CONFIG`     | Kind config file (if not set, uses kind-config.yaml or kind-custom.yaml) | *(none)* |
| `PACKAGE_MANAGER` | Package manager preference (brew, native)     | `auto`    |
| `FLUX_ENABLED`    | Enable GitOps with Flux                       | `false`   |
| `METALLB_ENABLED` | Enable MetalLB for LoadBalancer support       | `false`   |
| `INGRESS_ENABLED` | Enable NGINX Ingress Controller               | `false`   |
| `GITOPS_REPO`     | Git repository URL for Flux sync (if enabled) | *(none)*  |
| `GITOPS_BRANCH`   | Git branch to use for Flux sync               | `main`    |
| `SOFTWARE_STACK`  | Software stack to deploy                      | `sample`  |
| `NAMESPACE`       | Default namespace for app deployments         | `default` |

### Kind Configuration

HostK8s uses a 3-tier fallback system for Kind cluster configuration:

1. **KIND_CONFIG environment variable** - Explicit config override
2. **kind-config.yaml** - User's persistent custom configuration
3. **Functional defaults** - Uses kind-custom.yaml for complete functionality

```bash
# Tier 3: Functional defaults (recommended for beginners)
make start                    # Uses kind-custom.yaml automatically

# Tier 2: Custom configuration (persistent)
cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml
# Edit kind-config.yaml for your needs
make start

# Tier 1: Environment override (temporary)
KIND_CONFIG=kind-custom.yaml make start
KIND_CONFIG=extension/my-config make start
```

**Available Example Configurations:**
- `kind-custom.yaml` - Full-featured example with port mappings and registry support
- `kind-config-minimal.yaml` - Minimal configuration for testing
- `extension/kind-sample.yaml` - Extended configuration for complex setups

---

## Namespace Management

HostK8s supports deploying applications to custom namespaces using multiple syntax options for flexibility in different workflows.

### Namespace Syntax Options

**Default Deployment (default namespace):**
```bash
make deploy simple              # Deploys to 'default' namespace
```

**Positional Namespace Argument:**
```bash
make deploy simple testing      # Deploys to 'testing' namespace
make deploy complex staging     # Deploys to 'staging' namespace
make deploy helm-sample prod    # Deploys to 'prod' namespace
```

**Environment Variable:**
```bash
NAMESPACE=apps make deploy simple       # Deploys to 'apps' namespace
NAMESPACE=development make deploy complex
```

### Available Applications

| App Name | Type | Description |
|----------|------|-------------|
| `simple` | Basic | Single pod application for testing |
| `complex` | Intermediate | Multi-service app with Kustomization |
| `helm-sample` | Advanced | Full Helm chart with voting app |

### Namespace Examples

**Development Workflow:**
```bash
# Create isolated development environment
make deploy simple dev-john
make deploy complex integration-tests
NAMESPACE=feature-branch make deploy helm-sample
```

**Team Collaboration:**
```bash
# Each team member gets their own namespace
make deploy simple alice
make deploy simple bob
make status  # Shows apps across all namespaces
```

**Multi-Environment Testing:**
```bash
# Test same app in different environments
make deploy helm-sample dev
make deploy helm-sample staging
NAMESPACE=production make deploy helm-sample
```

### Namespace Management

- **Automatic Creation**: Namespaces are created automatically if they don't exist
- **Cleanup**: Empty namespaces are automatically removed when the last app is removed
- **Isolation**: Each namespace provides complete resource isolation
- **Status Visibility**: `make status` shows apps across all namespaces with namespace labels

---

# Test external status reporting
