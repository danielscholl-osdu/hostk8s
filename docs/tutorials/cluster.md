# Cluster Configuration

*Learn HostK8s cluster configuration by experiencing the development workflow trade-offs that drive configuration decisions*

## The Development Workflow Challenge

You're testing a microservice that connects to a database. Simple enough - but where should it run? Mixed with Kubernetes system components on a single node, or isolated on a dedicated worker? This choice affects everything from debugging capabilities to resource usage patterns.

**Current development environment problems:**
- **Resource competition** - Your app competes with API server and etcd for CPU/memory
- **Production mismatch** - Single-node doesn't reflect production scheduling behavior
- **Debugging complexity** - System components make it harder to isolate application issues
- **Iteration speed** - Need fast startup vs realistic testing environment

**The Configuration Dilemma:**
Most developers want both fast iteration AND production-like behavior, but traditional Kubernetes development forces you to choose one or the other.

## How HostK8s Solves This

HostK8s provides two cluster configurations that address different points in the development workflow:

- **Single-Node** (`kind-custom.yaml`) - Optimizes for speed and simplicity
- **Multi-Node** (`kind-worker.yaml`) - Provides production-like workload isolation

The key insight: **your cluster choice affects not just resources, but how closely your development matches production behavior.**

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

This configuration excels when you need:
- **Rapid prototyping** - 30-second cluster startup
- **Resource constraints** - Limited laptop memory/CPU
- **Simple applications** - Single service or basic microservices
- **Learning** - Simplified mental model

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

This configuration excels when you need:
- **Production-like testing** - Realistic workload placement
- **Resource isolation** - Apps don't compete with system components
- **Distributed applications** - Testing scheduling across nodes
- **Debugging complex issues** - Isolate app problems from system problems

## Core Configuration Concepts

### Node Roles and Scheduling

Both configurations teach you fundamental Kubernetes concepts you'll use throughout HostK8s:

**Node Roles:**
- **Control Plane** - Runs Kubernetes system components (API server, etcd, scheduler)
- **Worker** - Runs your application workloads

**Scheduling Behavior:**
- **Single-Node** - Everything runs together (faster, but mixed workloads)
- **Multi-Node** - Automatic separation (realistic, isolated debugging)

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

HostK8s uses a 3-tier system that lets you experiment without breaking your workflow:

### Testing Configurations
```bash
KIND_CONFIG=worker make start    # Try multi-node temporarily
```

### Personal Defaults
```bash
# Set your preferred configuration
cp infra/kubernetes/kind-worker.yaml infra/kubernetes/kind-config.yaml
make start                       # Always uses your preference
```

### System Defaults
```bash
make start                       # Uses functional defaults (kind-custom.yaml)
```

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

Cluster configuration isn't just about resources - it's about matching your development environment to your testing needs:

- **Single-node** optimizes for development speed and simplicity
- **Multi-node** provides production-like workload isolation and scheduling
- **Both support** the same development features (registry, storage, ingress)
- **Your choice** affects debugging, resource usage, and production similarity

The key insight: different development phases need different cluster configurations. HostK8s makes it easy to switch between them without losing your data or development workflow.
