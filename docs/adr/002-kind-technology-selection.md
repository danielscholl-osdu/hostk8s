# ADR-002: Kind Technology Selection

## Status
**Accepted** - 2025-01-12

## Context
HostK8s required a local Kubernetes solution that provides authentic Kubernetes behavior while being lightweight, stable, and developer-friendly. The solution must support the host-mode architecture, integrate well with Docker Desktop, and provide consistent behavior across Mac, Linux, and Windows WSL2 platforms.

## Decision
Use **Kind (Kubernetes in Docker)** as the core Kubernetes runtime for local development environments.

## Rationale
1. **Authentic Kubernetes**: Uses real Kubernetes components, not lightweight alternatives
2. **Host-Mode Compatible**: Designed to run containers directly on host Docker daemon
3. **Upstream Conformance**: Passes Kubernetes conformance tests, ensuring compatibility
4. **Mature and Stable**: Developed by Kubernetes SIG Testing, battle-tested in CI/CD
5. **Docker Integration**: Seamless integration with existing Docker Desktop installations
6. **Multi-Platform**: Consistent behavior across Mac, Linux, Windows WSL2

## Alternatives Considered

### 1. minikube
- **Pros**: Mature project, multiple driver options, good documentation
- **Cons**: VM-based by default, complex driver selection, resource overhead
- **Decision**: Rejected due to virtualization complexity and resource requirements

### 2. k3s/k3d
- **Pros**: Lightweight, fast startup, low resource usage
- **Cons**: Modified Kubernetes distribution, potential compatibility issues, limited ecosystem
- **Decision**: Rejected due to non-standard Kubernetes distribution

### 3. Docker Desktop Kubernetes
- **Pros**: Built-in, no additional installation, simple activation
- **Cons**: Single-node only, limited configuration options, tied to Docker Desktop versions
- **Decision**: Rejected due to inflexibility and upgrade coupling

### 4. MicroK8s
- **Pros**: Lightweight, snap-based installation, good for Ubuntu
- **Cons**: Snap dependency, Linux-only, non-standard networking
- **Decision**: Rejected due to platform limitations

### 5. Rancher Desktop
- **Pros**: Complete Docker Desktop alternative, built-in Kubernetes
- **Cons**: Large installation, additional complexity, less mature
- **Decision**: Rejected due to adoption overhead

## Technical Comparison

### Kubernetes Conformance
```
Kind:           ✅ Full conformance (upstream K8s)
minikube:       ✅ Full conformance (upstream K8s)
k3s:            ⚠️  Modified distribution (some features removed)
Docker Desktop: ✅ Full conformance (upstream K8s)
MicroK8s:       ✅ Full conformance (upstream K8s)
```

### Resource Requirements
```
Kind:           2GB RAM, 1 CPU (minimum)
minikube:       3GB RAM, 2 CPU (minimum)
k3s:            1GB RAM, 1 CPU (minimum)
Docker Desktop: 2GB RAM, 2 CPU (minimum)
MicroK8s:       2GB RAM, 1 CPU (minimum)
```

### Startup Performance
```
Kind:           30-60 seconds
minikube:       2-5 minutes (driver dependent)
k3s:            15-30 seconds
Docker Desktop: 1-2 minutes
MicroK8s:       1-3 minutes
```

### Platform Support
```
Kind:           Mac, Linux, Windows WSL2
minikube:       Mac, Linux, Windows (with drivers)
k3s:            Linux only (native), containers elsewhere
Docker Desktop: Mac, Linux, Windows
MicroK8s:       Linux only (native)
```

## Implementation Benefits

### Host-Mode Architecture
Kind's design philosophy aligns perfectly with host-mode:
```bash
# Kind cluster as single Docker container
docker ps
# CONTAINER ID   IMAGE                 COMMAND
# abc123def456   kindest/node:v1.33.1  "/usr/local/bin/entr…"
```

### Configuration Flexibility
```yaml
# kind-config.yaml - Customizable cluster configuration
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
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
```

### Standard Tooling Integration
```bash
# Standard kubectl commands work without modification
export KUBECONFIG=$(pwd)/data/kubeconfig/config
kubectl get nodes
kubectl apply -f manifests/
helm install myapp ./chart
```

## Consequences

**Positive:**
- **Authenticity**: Real Kubernetes behavior eliminates "works locally but not in production" issues
- **Tooling Compatibility**: All standard Kubernetes tools work without modification
- **Stability**: Mature project with extensive testing and CI/CD usage
- **Performance**: Optimized for container-based architecture
- **Community**: Strong community support and documentation

**Negative:**
- **Docker Dependency**: Requires Docker Desktop, tied to Docker ecosystem
- **Single-Node Limitation**: Multi-node clusters require additional complexity
- **Image Size**: kindest/node images are larger than minimal alternatives
- **Resource Usage**: Slightly higher resource usage than ultra-lightweight solutions

## Integration Points

### CI/CD Compatibility
Kind is extensively used in CI/CD environments:
```yaml
# GitHub Actions integration
- name: Create kind cluster
  uses: helm/kind-action@v1.4.0
  with:
    node_image: kindest/node:v1.33.1
```

### Kubernetes Version Support
Kind maintains compatibility with multiple Kubernetes versions:
```bash
# Version matrix supported
kind create cluster --image kindest/node:v1.31.1
kind create cluster --image kindest/node:v1.32.1
kind create cluster --image kindest/node:v1.33.1
```

## Success Criteria
- ✅ Kubernetes conformance test passing (100% compatibility)
- ✅ Cross-platform consistency (Mac, Linux, Windows WSL2)
- ✅ Integration with standard tooling (kubectl, helm, flux)
- ✅ Performance targets: cluster creation < 2 minutes
- ✅ Resource efficiency: baseline cluster < 2GB RAM
- ✅ Community support and long-term viability
