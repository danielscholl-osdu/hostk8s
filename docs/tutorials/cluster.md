# Cluster Configuration

*Learn HostK8s cluster configuration by experiencing the development workflow trade-offs that drive configuration decisions*

## The Development Workflow Challenge

You're testing a microservice that connects to a database. Simple enough, but where should it run? For basic development, you might just use Docker Compose or even run everything directly in your IDE with local database connections. When you need to test Kubernetes-specific behavior like service discovery, resource limits, or ingress routing, you could spin up a cloud cluster (AKS, EKS, GKE), but that brings cost, slow provisioning, and the overhead of managing shared cloud resources for what might be quick development experiments.

Once you've decided you need local Kubernetes for fast iteration, the next question becomes: should your application run mixed with Kubernetes system components on a single node, or isolated on a dedicated worker? This choice affects everything from debugging capabilities to resource usage patterns.

**The development spectrum dilemma:**
- **Too simple** - Docker Compose works for basic scenarios but can't test Kubernetes features
- **Cloud overhead** - AKS, EKS, GKE provide real Kubernetes but with cost, startup time, and shared resource constraints
- **Too complex** - Full production clusters are slow and resource-heavy for development
- **Resource competition** - Single-node Kubernetes mixes your app with system components
- **Production mismatch** - Need to test real scheduling but want fast iteration
- **Context switching** - Moving between different development environments breaks flow

**The Configuration Challenge:**
You need Kubernetes for testing service mesh, resource limits, or ingress behavior, but cloud services add cost and complexity while local solutions sacrifice either speed or realism. Traditional approaches force you to choose between realistic testing, development velocity, and cost control.

## How HostK8s Solves This

HostK8s solves this through **configurable cluster architectures** that let you match your environment to your specific development needs. Rather than forcing you into a one-size-fits-all solution, the platform provides a foundation where you can create clusters optimized for different scenarios.

**Built-in Starting Points:**
- **Single-Node** (`kind-custom.yaml`) - Optimizes for speed and simplicity
- **Multi-Node** (`kind-worker.yaml`) - Provides production-like workload isolation

**The Real Power: Custom Configurations**
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
⚙️  Control Plane: Ready
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

**Key Insight:** Your application shares resources directly with Kubernetes system components (API server, etcd, scheduler).

### When Single-Node Works Best

Single-node configuration becomes the obvious choice during the early phases of development. When you're rapidly iterating on an idea, the 30-second cluster startup time can be the difference between maintaining flow state and losing your train of thought. If you're working on a laptop with limited resources, running everything in a single container means you can still run a full Kubernetes environment without overwhelming your system.

This approach also shines when you're building simpler applications or learning Kubernetes fundamentals. The mental model is straightforward: one cluster, one place where everything runs, no complexity about where workloads land. You can focus on your application logic without worrying about the nuances of distributed systems.

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
⚙️  Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 45s)
   Node: hostk8s-control-plane
👷 Worker: Ready
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

**Key Insight:** Kubernetes automatically isolates your workloads from system components using node taints.

### Understanding Workload Scheduling

Check why applications avoid the control plane:

```bash
kubectl describe nodes | grep Taints
# hostk8s-control-plane: node-role.kubernetes.io/control-plane:NoSchedule
# hostk8s-worker: <none>
```

This **taint** prevents user applications from competing with critical system components for resources.

### When Multi-Node Works Best

Multi-node configuration becomes essential as your applications grow in complexity. When you're building distributed systems or preparing for production deployment, you need to understand how Kubernetes actually schedules workloads across different nodes. This configuration gives you that reality without the overhead of a full production cluster.

The isolation benefits become particularly valuable during debugging sessions. When something goes wrong in a single-node setup, you're often left wondering whether the issue is with your application, a resource contention problem with the Kubernetes control plane, or some interaction between them. With workload isolation, you can immediately rule out system component interference and focus on your application's actual behavior.

This setup also prepares you for production scenarios where your applications will run on dedicated worker nodes, helping you catch scheduling, resource, and networking issues early in your development cycle.

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

One of the most practical aspects of HostK8s is how it handles configuration management. The platform recognizes that developers need flexibility. Sometimes you want to experiment with different cluster types, sometimes you want to set a personal preference, and sometimes you just want things to work without thinking about it.

The 3-tier system addresses all these needs elegantly:

### Testing Configurations
```bash
KIND_CONFIG=worker make start    # Try multi-node temporarily
```

When you want to experiment with a different cluster configuration, just set the KIND_CONFIG environment variable. This is perfect for testing how your applications behave in different environments without changing your default setup.

### Personal Defaults
```bash
# Set your preferred configuration
cp infra/kubernetes/kind-worker.yaml infra/kubernetes/kind-config.yaml
make start                       # Always uses your preference
```

If you find yourself always using the same configuration (maybe you prefer multi-node for all your development), create a personal `kind-config.yaml` file. HostK8s will automatically detect and use this file, so `make start` always gives you exactly what you want.

### System Defaults
```bash
make start                       # Uses functional defaults (kind-custom.yaml)
```

When you don't specify anything and don't have a personal config, HostK8s falls back to the system default. This ensures that tutorials, examples, and new team members always get a working environment without any setup required.

## Making the Choice

Your cluster configuration choice affects your entire development workflow:

| Development Stage | Single-Node | Multi-Node |
|------------------|-------------|------------|
| **Prototyping** | ✅ Fast iteration | ⚠️ Slower startup |
| **Integration Testing** | ⚠️ Mixed workloads | ✅ Isolated workloads |
| **Debugging** | ⚠️ Shared resources | ✅ Clear separation |
| **Production Prep** | ❌ Unrealistic | ✅ Realistic behavior |

**The Pattern:** Start with single-node for speed, move to multi-node when you need production-like behavior.

## Building Toward Applications

The concepts you've learned here become the foundation for application deployment:

- **Node roles** determine where your applications run
- **Resource isolation** affects how applications interact
- **Workload scheduling** becomes important for multi-service applications
- **Storage mounts** enable persistent application data

In the [next tutorial](apps.md), you'll deploy increasingly complex applications and experience how cluster configuration choices affect application behavior, resource usage, and debugging capabilities.

## Summary

Cluster configuration isn't just about resources. It's about matching your development environment to your testing needs:

- **Single-node** optimizes for development speed and simplicity
- **Multi-node** provides production-like workload isolation and scheduling
- **Both support** the same development features (registry, storage, ingress)
- **Your choice** affects debugging, resource usage, and production similarity

The key insight: different development phases need different cluster configurations. HostK8s makes it easy to switch between them without losing your data or development workflow.
