# Kind Configuration Guide

Learn when and why to customize Kind cluster configurations through practical examples. This guide covers the key decisions you'll face when choosing between single-node and multi-node development clusters.

## Configuration Decision Framework

HostK8s provides two primary cluster configurations, each optimized for different development scenarios:

- **Single-Node** (`kind-custom.yaml`) - Control plane handles everything
- **Multi-Node** (`kind-worker.yaml`) - Dedicated worker node for applications

The choice depends on what you're testing and how closely you want to simulate production environments.

## Prerequisites

```bash
# Start with a clean environment
make clean
```

## Configuration 1: Single-Node Development

### When to Choose Single-Node
- **Quick prototyping** - Fast startup, minimal resources
- **Learning Kubernetes** - Simplified mental model
- **Simple applications** - Single service or basic microservices
- **Resource constraints** - Limited laptop memory/CPU

### Understanding the Configuration

```bash
# View the single-node configuration
cat infra/kubernetes/kind-custom.yaml
```

**Key Features:**
- **Single container** - Control plane runs everything
- **Registry support** - Local image development (ports 5001, 5443)
- **Persistent storage** - Mounts to `./data/storage` for PVCs
- **HTTP/HTTPS access** - Standard ingress on ports 8080/8443

### Deploy and Test

```bash
make start
make status
```

You'll see:
```
⚙️  Control Plane: Ready
   Status: Kubernetes v1.33.2 (up 30s)
```

Deploy a test application:
```bash
make deploy simple
curl http://localhost:8080/simple
```

**Resource Impact:** ~600MB RAM total, all workloads share control plane resources.

## Configuration 2: Multi-Node Development

### When to Choose Multi-Node
- **Production-like testing** - Separate control plane from workloads
- **Resource isolation** - System components don't compete with apps
- **Scheduling behavior** - Test node affinity, taints, tolerations
- **Distributed applications** - Apps that require multiple nodes

### Understanding the Configuration

```bash
# View the multi-node configuration
cat infra/kubernetes/kind-worker.yaml
```

**Key Features:**
- **Two containers** - Control plane + dedicated worker
- **Workload isolation** - Apps run only on worker node
- **Same registry/storage** - Identical development features
- **Standard roles** - `control-plane` and `worker` roles

### Deploy and Test

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

Test workload scheduling:
```bash
make deploy simple
kubectl get pods -o wide
# Shows pod running on hostk8s-worker (not control plane)
```

**Resource Impact:** ~600MB RAM total, but workloads isolated from control plane.

## Key Configuration Concepts

### Node Roles and Scheduling

**Single-Node:** Applications share resources with Kubernetes system components.

**Multi-Node:** Control plane has a taint that prevents user workloads from scheduling there:
```bash
kubectl describe nodes | grep Taints
# hostk8s-control-plane: node-role.kubernetes.io/control-plane:NoSchedule
# hostk8s-worker: <none>
```

This means your applications automatically get isolated from critical system components.

### Storage Configuration

Both configurations support persistent storage through host mounts:

```yaml
# In both configs
extraMounts:
- hostPath: ./data/storage    # Your project's data folder
  containerPath: /mnt/data    # Available inside containers
  readOnly: false
```

**Usage in PersistentVolumes:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-storage
spec:
  capacity:
    storage: 1Gi
  hostPath:
    path: /mnt/data           # Maps to ./data/storage
  storageClassName: local
```

### Local Registry Configuration

Both configurations include local registry support:

```yaml
# Registry configuration enables
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
    endpoint = ["http://registry.registry.svc.cluster.local:5000"]
```

**Development workflow:**
```bash
# Build and push to local registry
docker build -t localhost:5000/myapp .
docker push localhost:5000/myapp

# Deploy from local registry
kubectl create deployment myapp --image=localhost:5000/myapp
```

## Configuration Customization Patterns

### Adding Custom Storage Mounts

```yaml
# Add to any node in your config
extraMounts:
- hostPath: ./my-project-data
  containerPath: /mnt/project
  readOnly: false
```

### Customizing Port Mappings

```yaml
# Add custom port access
extraPortMappings:
- containerPort: 30090    # Kubernetes NodePort
  hostPort: 9090          # Access from laptop
  protocol: TCP
```

### Adding Node Labels

```yaml
# Custom labels for workload targeting
labels:
  environment: development
  workload-type: web
```

## Making Configuration Persistent

### Temporary Override (Testing)
```bash
KIND_CONFIG=worker make start    # One-time use
```

### Personal Default (Your Preference)
```bash
# Copy your preferred config as default
cp infra/kubernetes/kind-worker.yaml infra/kubernetes/kind-config.yaml
make start                       # Always uses your config
```

### System Default (Functional Baseline)
```bash
make start                       # Uses kind-custom.yaml automatically
```

## Resource and Performance Comparison

| Aspect | Single-Node | Multi-Node |
|--------|-------------|------------|
| **Startup Time** | ~30 seconds | ~45 seconds |
| **Memory Usage** | ~600MB total | ~600MB total |
| **Containers** | 1 (shared) | 2 (isolated) |
| **Scheduling** | Mixed workloads | Separated workloads |
| **Production-Like** | Basic | More realistic |

## Decision Tree

**Choose Single-Node when:**
- Getting started with Kubernetes
- Building simple applications
- Limited development resources
- Need fastest possible iteration

**Choose Multi-Node when:**
- Testing distributed applications
- Need workload isolation
- Simulating production scheduling
- Testing node-specific features

## Common Modifications

### Adding More Worker Nodes

```yaml
# Add to kind-worker.yaml
- role: worker
  image: kindest/node:v1.33.2
  labels:
    node-role.kubernetes.io/worker: ""
  extraMounts:
  - hostPath: /tmp/kind-storage-2
    containerPath: /mnt/storage
    readOnly: false
```

### Custom Networking

```yaml
# Modify networking section
networking:
  podSubnet: "172.16.0.0/16"      # Custom pod network
  serviceSubnet: "172.17.0.0/16"  # Custom service network
```

### Adding Registry Mirrors

```yaml
# Add to containerdConfigPatches
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["https://my-private-registry.com"]
```

## Next Steps

With your Kind configuration knowledge, explore:

**Application Deployment:**
```bash
# Test your custom cluster
make deploy simple      # Basic deployment
make deploy complex     # Multi-service app
```

**GitOps Integration:**
```bash
# Use custom config with automated deployment
KIND_CONFIG=worker make up sample
```

**Extension Development:**
```bash
# Create project-specific configurations
cp infra/kubernetes/kind-worker.yaml infra/kubernetes/extension/kind-myproject.yaml
```

## Summary

Kind configuration is about choosing the right development environment for your needs:

- **Single-node** optimizes for speed and simplicity
- **Multi-node** optimizes for realistic production testing
- **Both support** the same development features (registry, storage, ingress)
- **Customization** enables project-specific requirements

The key insight is that your configuration choice affects not just resources, but also how closely your development environment matches production behavior. Start simple with single-node, then move to multi-node when you need to test production-like scheduling and isolation.
