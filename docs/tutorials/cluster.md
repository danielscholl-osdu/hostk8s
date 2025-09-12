# Cluster Configuration

*Learn HostK8s cluster configuration by experiencing the development workflow trade-offs that drive configuration decisions*

## The Development Workflow Challenge

You're testing a microservice that connects to a database. Simple enough, but where should it run? For basic development, you might just use Docker Compose or even run everything directly in your IDE with local database connections. When you need to test Kubernetes-specific behavior like service discovery, resource limits, or ingress routing, you could spin up a cloud provider cluster, but that brings cost, slow provisioning, and the overhead of managing shared cloud resources for what might be quick development experiments.

Once you've decided you need local Kubernetes for fast iteration, the architectural decisions compound: should your application run mixed with Kubernetes system components on a single node, or isolated on a dedicated worker? How should networking be configured - basic CNI or service mesh? What about storage - ephemeral volumes or persistent data? These choices cascade through every aspect of development, affecting debugging capabilities, resource usage patterns, networking behavior, data persistence, and ultimately how closely your development environment mirrors your target deployment architecture.

**The development spectrum dilemma:**

*Speed vs Realism:*
- **Too simple** - Docker Compose works for basic scenarios but can't test Kubernetes features
- **Too complex** - Full production clusters are slow and resource-heavy for development

*Cost vs Access:*
- **Cloud overhead** - Cloud providers offer real Kubernetes but with cost, startup time, and vendor lock-in risks
- **Access constraints** - Cloud security policies often block direct access to cluster internals, limiting debugging and inspection

*Debuggability:*
- **Context switching** - Moving between different development environments breaks flow
- **Observability** - Fast access to logs, metrics, and the ability to toggle debug modes is essential for iterative development

**The Configuration Challenge:**
You need Kubernetes for testing service mesh, resource limits, or ingress behavior, but cloud services add cost, vendor coupling, and debugging access restrictions while local solutions sacrifice either speed or realism. Traditional approaches force you to choose between realistic testing, development velocity, platform independence, and debugging accessibility.

## How HostK8s Solves This

HostK8s solves this through **configurable cluster architecture patterns** that let you version control your development environment alongside your application code. Rather than forcing you into a one-size-fits-all solution, the platform provides the framework and patterns to create clusters optimized for your specific needs.

### Base Configuration

HostK8s provides a custom configuration that works out of the box for the samples in the project:

- **`kind-custom.yaml`** - Single-node configuration with essential features (ingress, registry, persistent storage)

Like the sample applications in this repository, this configuration is a **learning example** - real projects would typically create their own configurations tailored to their specific requirements.

### Real-World Configuration Examples

Projects create their own configurations based on their needs:
- **Data platforms** - Custom configurations with specialized storage and networking for large-scale data processing
- **Microservice projects** - Service mesh configurations that mirror their production Istio setup
- **CI environments** - Minimal resource configurations optimized for automated testing
- **Enterprise solutions** - Security-focused configurations that match corporate compliance requirements

### The Configuration-as-Code Pattern

Your cluster configuration becomes part of your project's infrastructure-as-code:
- Project contributors get identical environments
- CI systems replicate your exact setup
- Environment evolves alongside your application architecture
- Configuration decisions are documented and version controlled

The key insight: **your development environment architecture should be as intentional and version-controlled as your application architecture.**

## Using the Default Configuration

HostK8s starts with a functional single-node configuration by default:

```bash
make start
make status
```

You'll see:
```
🕹️ Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 30s)
```

**Default behavior:**
- Uses the built-in `kind-custom.yaml` configuration automatically
- One Docker container running everything
- ~30 second startup time
- Applications share resources with Kubernetes system components

Deploy an application to see the default behavior:

```bash
make deploy simple
kubectl get pods -o wide
# All pods running on hostk8s-control-plane

make clean
# Remove the cluster after exploration
```

**Single-Node Architecture:**
```
┌───────────────────────────────────────┐
│        hostk8s-control-plane          │
│  ┌─────────────┐ ┌─────────────────┐  │
│  │System       │ │Your             │  │
│  │Components   │ │Applications     │  │
│  │• API Server │ │• simple-app     │  │
│  │• etcd       │ │• voting-app     │  │
│  │• scheduler  │ │                 │  │
│  └─────────────┘ └─────────────────┘  │
└───────────────────────────────────────┘
```

## Creating A Custom Configuration

The most common way to customize HostK8s is by creating your own default configuration.

When you start the cluster, HostK8s looks for a custom configuration file first. If not, it falls back to the built-in default configuration.

**Understanding the files:**
- **`kind-custom.yaml`** - System-provided base configuration (don't edit this)
- **`kind-config.yaml`** - Your personal override (you create and customize this)

**Your configuration workflow:**
1. **Copy the base** - Start with the working single-node configuration
2. **Customize as needed** - Add worker nodes, change networking, modify ports
3. **Use automatically** - Your customizations become the new default

Create your personal default:

```bash
# Copy the base configuration to become your default
cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml
```

Once you have `kind-config.yaml`, `make start` will automatically detect and use it instead of the system default—giving you custom defaults with the safety net of a known-good base.

The `kind-custom.yaml` includes commented examples for the two most common customizations: **adding a worker node** and **expanding network subnets**. Simply uncomment the sections you need:

**Worker Node**: Uncomment the worker node section to isolate applications from system components.

**Network Subnets**: The default Class B networks (`172.20.0.0/24` and `172.20.1.0/24`) avoid common home network conflicts. For larger deployments or different IP addressing, modify the network block.

For additional configuration options, see the [Kind Configuration Guide](https://kind.sigs.k8s.io/docs/user/configuration/).


### Test Your Custom Configuration

Start your cluster with the customized configuration:

```bash
# Uses your custom configuration automatically
# Ingress is enabled by default
make start
make status
```

You should see your worker node is running:
```
🕹️ Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 45s)
   Node: hostk8s-control-plane
🚜 Worker: Ready
   Status: Kubernetes v1.33.2 (up 31s)
   Node: hostk8s-worker
```

### Verify Your Changes

Deploy an application to verify worker node scheduling:

```bash
make deploy simple
kubectl get pods -o wide
# Pod should run on hostk8s-worker (not control-plane)

make clean
```

**Multi-Node Architecture:**
```
┌───────────────────────────────────┐  ┌───────────────────────────────────┐
│     hostk8s-control-plane         │  │         hostk8s-worker            │
│  ┌─────────────────────────────┐  │  │  ┌─────────────────────────────┐  │
│  │System Components            │  │  │  │Your Applications            │  │
│  │• API Server                 │  │  │  │• simple-app                 │  │
│  │• etcd                       │  │  │  │• voting-app                 │  │
│  │• scheduler                  │  │  │  │• databases                  │  │
│  │(Tainted - No User Apps)     │  │  │  │(User Workloads)             │  │
│  └─────────────────────────────┘  │  │  └─────────────────────────────┘  │
└───────────────────────────────────┘  └───────────────────────────────────┘
```

**What you've accomplished:**
- **Added worker node isolation** - applications run separately from system components
- **Personal default configuration** - your project can replicate this setup

---

### Multiple Configuration Support

**Advanced usage:** HostK8s also supports multiple named configurations for different scenarios (local vs cloud, minimal vs full-featured, etc.):

```bash
# Uses infra/kubernetes/kind-my-config.yaml
make start my-config
```

**Configuration priority:**
1. **Named configuration:** `make start worker` → `kind-worker.yaml` (if you created it)
2. **Personal default:** `make start` → `kind-config.yaml` (if you created it)
3. **System fallback:** `make start` → `kind-custom.yaml` (built-in base)

This layered fallback approach ensures your workflow always has a safe default. At the same time, it gives you the flexibility to maintain specialized configurations for different deployment scenarios.

---

## What Comes Next

You've now experienced the key tradeoffs in Kubernetes cluster configuration: how node roles, resource isolation, and scheduling behavior shape your development workflow.

These concepts form the foundation for application development. In the next tutorial, you'll:
- Deploy complex, multi-service applications
- Experience how configuration choices impact application behavior and performance
- Work with persistent storage and service discovery patterns

The cluster architecture decisions you've learned here will directly affect everything you build on top.

👉 Continue to: [Application Deployment](apps.md)
