# Cluster Configuration

*Learn HostK8s cluster configuration by experiencing the development workflow trade-offs that drive configuration decisions*

## The Development Workflow Challenge

You're testing a microservice that connects to a database. Simple enough, but where should it run? For basic development, you might just use Docker Compose or even run everything directly in your IDE with local database connections. When you need to test Kubernetes-specific behavior like service discovery, resource limits, or ingress routing, you could spin up a cloud provider cluster, but that brings cost, slow provisioning, and the overhead of managing shared cloud resources for what might be quick development experiments.

Once you've decided you need local Kubernetes for fast iteration, the next question becomes: should your application run mixed with Kubernetes system components on a single node, or isolated on a dedicated worker? This choice affects everything from debugging capabilities to resource usage patterns.

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

HostK8s solves this through **configurable cluster architectures** that let you match your environment to your specific development needs. Rather than forcing you into a one-size-fits-all solution, the platform provides a foundation where you can create clusters optimized for different scenarios.

**Built-in Starting Points:**
- **Single-Node** (`kind-custom.yaml`) - Optimizes for speed and simplicity
- **Multi-Node** (`kind-worker.yaml`) - Provides production-like workload isolation

**Beyond Defaults: Tailoring Your Cluster**
But these are just starting points. You can create configurations optimized for your specific needs:
- **High-scale testing** - Multi-node clusters with more workers to test distributed applications
- **Resource-constrained development** - Minimal single-node for CI environments or laptops
- **Cloud-simulation** - Configurations that mirror your production cloud provider's node structure
- **Specialized networking** - Custom CNI configurations for service mesh testing
- **Storage-focused** - Multiple persistent volumes for database-heavy applications

**The Configuration Philosophy:**
Your cluster configuration becomes part of your project's infrastructure-as-code. Team members get identical environments, CI systems can replicate your exact setup, and you can evolve your development environment alongside your application architecture.

The key insight: **your cluster choice affects not just resources, but how closely your development matches your specific production requirements.**

## Prerequisites

Start with a clean environment to experience the differences:

```bash
make clean
```

## Experience 1: Single-Node Development

### The Fast Iteration Approach

Let's start with single-node to understand when speed matters most.

```bash
make start
make status
```

You'll see:
```
Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 30s)
```

**What just happened:**
- One Docker container running everything
- ~30 second startup time
- ~600MB RAM total usage

Deploy an application to see resource sharing:

```bash
make deploy simple
curl http://localhost:8080/simple
```

Check where your application landed:

```bash
kubectl get pods -o wide
# All pods running on hostk8s-control-plane
```

**Architecture:**
```
┌─────────────────────────────────────┐
│        hostk8s-control-plane       │
│  ┌─────────────┐ ┌─────────────────┐│
│  │System       │ │Your             ││
│  │Components   │ │Applications     ││
│  │• API Server │ │• simple-app     ││
│  │• etcd       │ │• voting-app     ││
│  │• scheduler  │ │                 ││
│  └─────────────┘ └─────────────────┘│
└─────────────────────────────────────┘
```

**Key Insight:** Your application shares resources directly with Kubernetes system components (API server, etcd, scheduler).

## Experience 2: Multi-Node Development

### The Production-Like Approach

Now let's experience workload isolation with a multi-node cluster:

```bash
make clean
KIND_CONFIG=worker make start
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

**What changed:**
- Two Docker containers with defined roles
- ~45 second startup (slightly longer)
- Same ~600MB RAM total, but isolated

Deploy the same application:

```bash
make deploy simple
kubectl get pods -o wide
# Pod now running on hostk8s-worker (not control plane)
```

**Architecture:**
```
┌─────────────────────────────────────┐ ┌─────────────────────────────────────┐
│     hostk8s-control-plane          │ │        hostk8s-worker              │
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

**Key Insight:** Kubernetes automatically isolates your workloads from system components using node taints.

### Understanding Workload Scheduling

Ever wonder how Kubernetes decides where your app runs? Here's the key mechanism:

Check why applications avoid the control plane:

```bash
kubectl describe nodes | grep Taints
# hostk8s-control-plane: node-role.kubernetes.io/control-plane:NoSchedule
# hostk8s-worker: <none>
```

This **taint** prevents user applications from competing with critical system components for resources.

## Core Configuration Concepts

### Node Roles and Scheduling

Understanding how Kubernetes schedules workloads is crucial for everything you'll do in HostK8s. Both cluster configurations teach you these fundamentals, but in different ways.

In Kubernetes, nodes have specific roles that determine what runs on them. The **control plane** nodes handle the brain functions of the cluster. They run the API server that receives your kubectl commands, etcd that stores cluster state, and the scheduler that decides where your applications should run. **Worker** nodes are where your actual applications live and execute.

The beauty of the multi-node setup is that it shows you how Kubernetes automatically enforces this separation through taints. When you deploy an application, Kubernetes looks at each node and says "can this workload run here?" The control plane node says "no, I'm tainted for system components only," so your application lands on the worker node where it belongs. This automatic orchestration is what makes Kubernetes powerful in production environments.

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

The experiences you just completed show the core tradeoff: single-node prioritizes development speed while multi-node provides production-like isolation. Your choice depends on what you're optimizing for in your current development phase.

Most developers start with single-node for rapid iteration, then move to multi-node when they need to debug workload scheduling, test resource isolation, or prepare for production deployment.

## Building Toward Applications

The concepts you've learned here become the foundation for application deployment:

- **Node roles** determine where your applications run
- **Resource isolation** affects how applications interact
- **Workload scheduling** becomes important for multi-service applications
- **Storage mounts** enable persistent application data

In the [next tutorial](apps.md), you'll deploy increasingly complex applications and experience how cluster configuration choices affect application behavior, resource usage, and debugging capabilities.

## Summary

Cluster configuration shapes your entire development experience. Through hands-on experience, you've seen how single-node optimizes for speed while multi-node provides production-like isolation. Both configurations support the same core features (storage, registry, ingress), but excel in different development phases.

The key insight: different development stages benefit from different cluster architectures. HostK8s makes it easy to switch between them without losing your data or development workflow.
