# Cluster Configuration

*Learn HostK8s cluster configuration by experiencing the development workflow trade-offs that drive configuration decisions*

## The Development Workflow Challenge

You're testing a microservice that connects to a database. Simple enough, but where should it run? For basic development, you might just use Docker Compose or even run everything directly in your IDE with local database connections. When you need to test Kubernetes-specific behavior like service discovery, resource limits, or ingress routing, you could spin up a cloud provider cluster, but that brings cost, slow provisioning, and the overhead of managing shared cloud resources for what might be quick development experiments.

Once you've decided you need local Kubernetes for fast iteration, the architectural decisions compound: should your application run mixed with Kubernetes system components on a single node, or isolated on a dedicated worker? How should networking be configured - basic CNI or service mesh? What about storage - ephemeral volumes or persistent data? These choices cascade through every aspect of development, affecting debugging capabilities, resource usage patterns, networking behavior, data persistence, and ultimately how closely your development environment mirrors your target deployment architecture.

**The development spectrum dilemma:**

*Speed vs Realism:*
- **Too simple** - Docker Compose works for basic scenarios but can't test Kubernetes features
- **Too complex** - Full production clusters are slow and resource-heavy for development
- **Resource competition** - Single-node Kubernetes mixes your app with system components
- **Production mismatch** - Need to test real scheduling but want fast iteration

*Cost vs Access:*
- **Cloud overhead** - Cloud providers offer real Kubernetes but with cost, startup time, and vendor lock-in risks

*Debuggability:*
- **Context switching** - Moving between different development environments breaks flow
- **Access restrictions** - Cloud security constraints block direct debugging connections to cluster services

**The Configuration Challenge:**
You need Kubernetes for testing service mesh, resource limits, or ingress behavior, but cloud services add cost, vendor coupling, and debugging access restrictions while local solutions sacrifice either speed or realism. Traditional approaches force you to choose between realistic testing, development velocity, platform independence, and debugging accessibility.

## How HostK8s Solves This

HostK8s solves this through **configurable cluster architecture patterns** that let you version control your development environment alongside your application code. Rather than forcing you into a one-size-fits-all solution, the platform provides the framework and patterns to create clusters optimized for your specific needs.

### Sample Configuration Patterns

HostK8s includes example configurations that demonstrate common patterns:

- **Single-Node** (`kind-custom.yaml`) - Shows fast iteration setup
- **Multi-Node** (`kind-worker.yaml`) - Demonstrates workload isolation patterns

Like the sample applications in this repository, these configurations are **learning examples** - real projects create their own configurations tailored to their specific requirements.

### Real-World Configuration Examples

Teams create their own configurations based on their needs:
- **Data platforms** - Custom configurations with specialized storage and networking for large-scale data processing
- **Microservice teams** - Service mesh configurations that mirror their production Istio setup
- **CI environments** - Minimal resource configurations optimized for automated testing
- **Enterprise teams** - Security-focused configurations that match corporate compliance requirements

### The Configuration-as-Code Pattern

Your cluster configuration becomes part of your project's infrastructure-as-code:
- Team members get identical environments
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
Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 30s)
```

**Default behavior:**
- Uses `infra/kubernetes/kind-custom.yaml` automatically
- One Docker container running everything
- ~30 second startup time
- Applications share resources with Kubernetes system components

Deploy an application to see the default behavior:

```bash
make deploy simple
kubectl get pods -o wide
# All pods running on hostk8s-control-plane
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

## Using Sample Configurations

HostK8s uses **convention-based naming** for configurations. When you run `make start worker`, it automatically finds and uses `infra/kubernetes/kind-worker.yaml`.

```bash
make clean
make start worker
make status
```

You'll see:
```
Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 45s)
   Node: hostk8s-control-plane
Worker: Ready
   Status: Kubernetes v1.33.2 (up 31s)
   Node: hostk8s-worker
```

**Convention-based pattern:**
- `make start worker` → uses `infra/kubernetes/kind-worker.yaml`
- `make start minimal` → uses `infra/kubernetes/kind-config-minimal.yaml`
- `make start` → uses `infra/kubernetes/kind-config.yaml` (if exists) or `kind-custom.yaml` (default)

Deploy the same application to see the difference:

```bash
make deploy simple
kubectl get pods -o wide
# Pod now running on hostk8s-worker (not control plane)
```

**Multi-Node Architecture:**
```
┌─────────────────────────────────────┐ ┌─────────────────────────────────────┐
│     hostk8s-control-plane           │ │        hostk8s-worker               │
│  ┌─────────────────────────────────┐│ │  ┌─────────────────────────────────┐│
│  │System Components                ││ │  │Your Applications                ││
│  │• API Server                     ││ │  │• simple-app                     ││
│  │• etcd                           ││ │  │• voting-app                     ││
│  │• scheduler                      ││ │  │• custom services                ││
│  │                                 ││ │  │                                 ││
│  │(Tainted: NoSchedule)            ││ │  │(Clean: Accepts workloads)       ││
│  └─────────────────────────────────┘│ │  └─────────────────────────────────┘│
└─────────────────────────────────────┘ └─────────────────────────────────────┘
```

**Why applications avoid the control plane:**

```bash
kubectl describe nodes | grep Taints
# hostk8s-control-plane: node-role.kubernetes.io/control-plane:NoSchedule
# hostk8s-worker: <none>
```

The control plane node is "tainted" to prevent user applications from competing with system components for resources.

## Creating Your Custom Configuration

Let's create a custom configuration by starting with the single-node setup and adding a worker node plus custom networking. This demonstrates the two most common modifications teams make.

### Step 1: Create Your Default Configuration

Copy the single-node configuration as your starting point:

```bash
# Copy the single-node configuration as a base
cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml
```

Once you create `infra/kubernetes/kind-config.yaml`, it becomes your **personal default**. Running `make start` (without specifying a configuration name) will use this file automatically.

### Step 2: Add a Worker Node

Open your configuration file and add a worker node:

```bash
# Edit your custom configuration
vi infra/kubernetes/kind-config.yaml
```

Find the `nodes:` section and add a worker:

```yaml
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
    - containerPort: 80
      hostPort: 8080
      listenAddress: "127.0.0.1"
      protocol: TCP
    - containerPort: 443
      hostPort: 8443
      listenAddress: "127.0.0.1"
      protocol: TCP
    - containerPort: 6443
      hostPort: 6443
- role: worker  # Add this line
```

### Step 3: Customize Network Subnets

Add custom networking to avoid conflicts with your VPN or corporate network:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
# Add custom networking
networking:
  podSubnet: "10.240.0.0/16"
  serviceSubnet: "10.0.0.0/16"
nodes:
- role: control-plane
  # ... rest of configuration
- role: worker
```

### Step 4: Test Your Custom Configuration

Start your custom cluster and verify the changes:

```bash
# Your custom configuration is now the default
make start
make status
```

You should see your worker node is running:
```
Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 45s)
   Node: hostk8s-control-plane
Worker: Ready
   Status: Kubernetes v1.33.2 (up 31s)
   Node: hostk8s-worker
```

### Step 5: Verify Your Changes

Check that your custom pod and service subnets are configured:

```bash
# Check cluster network configuration
kubectl cluster-info dump | grep -E "pod-subnet|service-subnet"
```

You should see your custom networking values:
```
"--pod-subnet=10.240.0.0/16"
"--service-subnet=10.0.0.0/16"
```

Deploy an application to verify worker node scheduling:

```bash
make deploy simple
kubectl get pods -o wide
# Pod should run on hostk8s-worker (not control-plane)
```

**What you've accomplished:**
- **Added worker node isolation** - applications run separately from system components
- **Custom networking** - avoided conflicts with corporate/VPN networks
- **Personal default configuration** - your team can replicate this setup

### Step 6: Share With Your Team

Since `kind-config.yaml` is gitignored by default, you can create a team configuration:

```bash
# Create a team configuration that can be version controlled
cp infra/kubernetes/kind-config.yaml infra/kubernetes/kind-istio.yaml

# Team members can use it with:
# make start istio
```

### Understanding the Configuration Hierarchy

HostK8s uses this priority order:

1. **Named configuration:** `make start worker` → `kind-worker.yaml`
2. **Personal default:** `make start` → `kind-config.yaml` (if exists)
3. **System fallback:** `make start` → `kind-custom.yaml` (built-in default)

This system lets you:
- **Experiment** with named configurations (`make start minimal`)
- **Set personal preferences** with `kind-config.yaml`
- **Always have working defaults** via `kind-custom.yaml`

## Core Configuration Concepts

### Node Roles and Scheduling

Understanding how Kubernetes schedules workloads is crucial for everything you'll do in HostK8s. Both cluster configurations teach you these fundamentals, but in different ways.

In Kubernetes, nodes have specific roles that determine what runs on them. The **control plane** nodes handle the brain functions of the cluster. They run the API server that receives your kubectl commands, etcd that stores cluster state, and the scheduler that decides where your applications should run. **Worker** nodes are where your actual applications live and execute.

**How Taints Enforce Separation:**

The multi-node setup shows you how Kubernetes automatically enforces this separation through taints. When you deploy an application, Kubernetes looks at each node and asks "can this workload run here?" The control plane node says "no, I'm tainted for system components only," so your application lands on the worker node where it belongs.

This **taint** (`node-role.kubernetes.io/control-plane:NoSchedule`) prevents user applications from competing with critical system components for resources. This automatic orchestration is what makes Kubernetes powerful in production environments - your workloads get scheduled appropriately without manual intervention.

### Storage for Development

Both configurations support persistent data in your project:

```yaml
# Both configs include
extraMounts:
- hostPath: ./data/storage    # Your project's persistent data
  containerPath: /mnt/data    # Available inside containers
```

**Why this matters:** Your databases and application data survive cluster restarts - essential for development iteration.

### Local Registry Support

Both configurations include local registry for development workflows:

```bash
# Build and push to local registry
docker build -t localhost:5000/myapp .
docker push localhost:5000/myapp

# Deploy from local registry
kubectl create deployment myapp --image=localhost:5000/myapp
```

**Why this matters:** Fast development cycles without pushing to external registries.

## Configuration Management

HostK8s uses a 3-tier configuration system that balances flexibility with simplicity:

**Tier 1: Temporary Override**
```bash
KIND_CONFIG=worker make start    # Try multi-node temporarily
```

**Tier 2: Personal Default**
```bash
cp infra/kubernetes/kind-worker.yaml infra/kubernetes/kind-config.yaml
make start                       # Always uses your preference
```

**Tier 3: System Fallback**
```bash
make start                       # Uses functional defaults (kind-custom.yaml)
```

This progression ensures you can experiment (tier 1), set personal preferences (tier 2), or rely on working defaults (tier 3) without configuration complexity.

## Making the Choice

Your hands-on experience shows the fundamental tradeoff: single-node prioritizes speed, multi-node provides realistic isolation. Most developers start with single-node for rapid iteration, then move to multi-node when they need production-like workload scheduling and debugging clarity.

## Building Toward Applications

The concepts you've learned here become the foundation for application deployment:

- **Node roles** determine where your applications run
- **Resource isolation** affects how applications interact
- **Workload scheduling** becomes important for multi-service applications
- **Storage mounts** enable persistent application data

In the [next tutorial](apps.md), you'll deploy increasingly complex applications and experience how cluster configuration choices affect application behavior, resource usage, and debugging capabilities.

## Summary

Cluster configuration shapes your entire development experience. As you experienced, the architectural choices cascade through networking, storage, debugging, and scheduling behavior. Both configurations support the same core features, but serve different development needs.

The key insight: different development stages benefit from different cluster architectures. HostK8s makes it easy to switch between them without losing your data or development workflow.
