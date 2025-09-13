# Platform Development

*Complete inner-loop cycle within a local platform environment*

## The Challenge

You've configured clusters, deployed applications, orchestrated software stacks, and understood how components work. Now comes the real test: **developing within a platform environment**.

Development starts simple. A single web app works great locally with docker-compose providing databases and basic services. But modern applications don't run in isolation. They integrate with platform infrastructure that can't be easily replicated.

Consider the integration challenges that emerge: Your application needs to authenticate through an Istio service mesh that requires real mesh behavior. You're debugging Elasticsearch queries that need a properly configured cluster with real indexing patterns. Your code integrates with Airflow workflows that require actual DAG orchestration and worker scaling. You need to test database performance under real connection pooling and transaction loads.

These platform capabilities can't be mocked or simplified without losing the behaviors you need to develop against. But setting up and maintaining this infrastructure becomes a major distraction from your actual development task.

| Development Approach | Advantages | Limitations |
|---------------------|------------|-------------|
| **Isolated Development** | Fast iteration with live refresh<br>Simple setup with docker-compose<br>Full debugging capabilities | Can't replicate platform behaviors<br>Missing service mesh, orchestration, scaling patterns |
| **Cloud Platform Development** | Real platform infrastructure<br>Authentic service interactions<br>Complete integration testing | Security barriers to infrastructure access<br>Complex setup and teardown processes<br>Cost and resource constraints |
| **Manual Platform Setup** | Control over infrastructure<br>Custom configurations possible | Requires infrastructure expertise<br>Time-consuming setup and maintenance<br>Inconsistent environments |

**The Core Problem:**
You need rapid iteration on code that integrates with complex platform infrastructure, including the ability to change code, deploy it to the platform, and immediately test the integration behavior. Traditional approaches force you to choose between development velocity and platform fidelity. You either develop in isolation and miss critical platform behaviors, or get trapped in slow outer-loop processes: submitting merge requests, waiting for CI/CD pipelines, and getting feedback hours later instead of seconds. HostK8s enables a faster inner-loop process where you spend time building applications rather than managing infrastructure or waiting for validation cycles.

## The Solution

HostK8s solves this through **hybrid development workflows** that bridge local iteration with platform integration. You develop locally when you need speed, then deploy to Kubernetes when you need to test integration with platform components.

The key insight: your development workflow should seamlessly transition between local iteration and platform integration without losing momentum. The cluster configurations, application contracts, and shared components from previous tutorials enable this fluid transition.

### The HostK8s Development Philosophy

Development workflows build directly on the patterns you've learned:
- **Cluster configurations** provide the infrastructure foundation for development
- **Application contracts** enable consistent deployment regardless of source code changes
- **Shared components** eliminate the overhead of managing development dependencies
- **Source-to-deployment** bridges the gap between code changes and running services

Instead of developing in isolation and then deploying to real infrastructure, HostK8s creates a unified workflow where development iteration happens within the context of your target infrastructure.

## The Platform

Let's start by understanding what you're building toward. This sample application demonstrates a complete microservices architecture that you'll deploy.

You can explore the source code structure in [`src/sample-app/`](../../src/sample-app/):
```
sample-app/
├── vote/                   # Python voting frontend
├── result/                 # Node.js results dashboard
├── worker/                 # .NET background processor
├── seed-data/              # Database initialization
├── docker-compose.yml      # Local development environment
├── docker-bake.hcl         # Multi-service build configuration
├── README.md               # Development setup instructions
└── .gitignore              # Version control exclusions
```

This represents the reality of modern application development: multiple services in different languages that must work together.

### Sample Application Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                Local Development Environment                 │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │    Vote     │  │   Result    │  │   Worker    │           │
│  │  (Python)   │  │ (Node.js)   │  │   (.NET)    │           │
│  │ Port: 5000  │  │ Port: 5001  │  │(Background) │           │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘           │
│         │                │                │                  │
│         └────────────────┼────────────────┘                  │
│                          │                                   │
│              ┌───────────┼───────────┐                       │
│              │                       │                       │
│         ┌────▼─────┐           ┌─────▼─────┐                 │
│         │  Redis   │           │PostgreSQL │                 │
│         │ (Cache)  │           │(Database) │                 │
│         └──────────┘           └───────────┘                 │
└──────────────────────────────────────────────────────────────┘
```

### Isolated Development

Before understanding how HostK8s enhances development workflows, let's see how development teams typically work in isolation. The sample application demonstrates a complete microservices architecture that a development team might build in their own repository.

In normal team development, you'd clone the application repository and work entirely within that codebase. In the `src/sample-app` directory:

```bash
# Start the local development environment
docker compose up -d

# Stop the local development environment when finished
docker compose down
```

Once all services are running, you can interact with the application:
- **Vote interface**: http://localhost:8081/vote/
- **Results dashboard**: http://localhost:8081/result/

This is the standard development workflow that teams use regardless of HostK8s. Developers make code changes, and thanks to live refresh configuration, the UI automatically updates as files are saved. The development team has their own repository, their own docker-compose setup, and their own development practices.

## The Build Problem

Isolated development works great for rapid iteration, but we need to build images of our code so that we can deploy them in the platform. This lets us test how our application behaves within the platform environment.

### HostK8s Integration

HostK8s provides a **convention-based architecture** that can integrate with any source code. The `src/sample-app` is included in the HostK8s repository for convenience, but demonstrates how any team's existing code can be integrated.

A developer can clone their application code into the `src/` directory and immediately get:
- All the benefits of their normal isolated development workflow
- Plus the ability to test integration with complete Kubernetes infrastructure
- Without changing their existing development practices

### The Build Contract

The convention-based architecture works through specific contracts that applications must provide. The key contract is a **bake file** that defines how the source code should be built into container images.

When you run `make build <directory>`, HostK8s expects to find a `docker-bake.hcl` file that knows how to:
- Build all services in the application
- Tag images appropriately for the cluster registry
- Handle multi-service builds efficiently

This contract allows HostK8s to work with any application structure while maintaining consistent build and deployment workflows.

### Setting Up the Platform

To build and deploy applications to Kubernetes, we need a platform environment with a local container registry where built images can be stored.

**Build Process Architecture:**

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   Source Code   │    │  Build Process  │    │ Cluster Registry │
│                 │    │                 │    │                  │
│  ┌────────────┐ │    │ ┌─────────────┐ │    │ ┌──────────────┐ │
│  │    vote    │ ├────► │Docker Build │ ├────► │localhost:5000│ │
│  │   result   │ │    │ │Multi-Service│ │    │ │   Images     │ │
│  │   worker   │ │    │ │   Images    │ │    │ │              │ │
│  └────────────┘ │    │ └─────────────┘ │    │ └──────────────┘ │
└─────────────────┘    └─────────────────┘    └──────────────────┘
                                 │
                           ┌─────▼─────┐
                           │   Tag     │
                           │ & Push    │
                           └───────────┘
```

Start a HostK8s cluster with the registry and ingress addons needed for platform development:

```bash
# Windows: --> $env:ENABLE_REGISTRY="true"
export ENABLE_REGISTRY=true

make start
make build src/sample-app
make status
```

HostK8s starts with registry and ingress capabilities, then uses the docker-bake.hcl contract to build all services. Built images are tagged and pushed to the local cluster registry automatically, making them available for deployment using the same application contracts and shared components you've already mastered.

You can explore the registry UI at http://localhost:8080/registry/ to see your built images. Browse the repository to view the vote, result, and worker images that were just pushed to your local registry.

## The Secrets Problem

You've built your application images and pushed them to the registry. But applications need more than just images to run in Kubernetes. They need database credentials, API keys, and other sensitive data.

### Adding Secret Management

We need a place to securely store and manage secrets. Let's add Vault to our platform but do this without losing the images we've already built. Storage in hostk8s can be persistant and survive a stop or restart of the cluster which essentially destroys the cluster but not the persistant data available to it.

```bash
# Windows: --> $env:ENABLE_VAULT="true"
export ENABLE_VAULT=true

make restart
make status
```

You can explore the empty Vault UI at http://localhost:8080/ui/ (no secrets yet) using the default token `hostk8s`.

### Secret Contracts

We need to be able to declare what secrets our applications require in code, but allow certain secret values to be generated rather than hardcoded. Flux has no capabilities for this and assumes that secrets exist as Kubernetes objects prior to starting any software components. This creates a fundamental timing problem: our declarative code needs to specify secret requirements, but the actual secret values must be generated and available before deployment begins.

HostK8s solves the secrets problem through **secret contracts** - declarative specifications that tell the platform what credentials your application needs without hardcoding actual values.

> 📖 **Learn more**: [Secret Contracts](../concepts/secret-contracts.md)

Here's a simplified example:

```yaml
# hostk8s.secrets.yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: sample-app
spec:
  secrets:
    - name: redis-commander-credentials
      namespace: redis
      data:
        - key: username
          value: admin
        - key: password
          generate: password
          length: 12
```

You can explore the complete secret contract in [`software/stacks/sample-app/hostk8s.secrets.yaml`](../../software/stacks/sample-app/hostk8s.secrets.yaml) to see how secrets for a full stack are declared.

## The Storage Problem

We just demonstrated that the platform preserves images across restarts. But shouldn't database data persist as well? Applications need persistent storage that survives removal and stoppage of the entire Kubernetes cluster.

### Storage Contracts

HostK8s uses **storage contracts** to declare persistent storage requirements. Applications specify what storage they need without worrying about the underlying implementation details.

> 📖 **Learn more**: [Storage Contracts](../concepts/storage-contracts.md)

Here's a simplified example:

```yaml
# hostk8s.storage.yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: sample-app
spec:
  volumes:
    - name: postgres-data
      size: 1Gi
      path: /var/lib/postgresql/data
```

You can explore the complete storage contract in [`software/stacks/sample-app/hostk8s.storage.yaml`](../../software/stacks/sample-app/hostk8s.storage.yaml) to see how PostgreSQL database storage is declared.


## Bringing up the stack

Now run your locally-built application on the platform. HostK8s will process the dependency contracts first, then bring up your stack with all requirements satisfied:

```bash
# Bring up the complete software stack
make up sample-app
make status
```

You'll see the sample-app running in the platform integrated with the necessary components.

## HostK8s Platform Summary

You've seen how HostK8s **cluster configurations** can be customized and extended to support different infrastructure needs. Individual **applications** are easy to **deploy** with consistent contracts, while reusable **components** can be composed into complete **software stacks**. The solution comes together as a full development **platform** through **secret contracts** and **storage contracts**, all managed through a unified **make** command interface. This eliminates the traditional choice between development speed and platform integration. You get both fast local development and complete Kubernetes capabilities for testing how your applications behave in the platform environment.

HostK8s is a local Kubernetes platform that bridges the gap between local development velocity and production infrastructure complexity, providing developers with complete development environments where they can build, test, and iterate on modern applications with confidence.
