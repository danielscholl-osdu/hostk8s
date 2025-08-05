# ADR-001: Host-Mode Architecture

## Status
**Accepted** - 2025-07-28

## Context
Local Kubernetes development environments face stability and performance challenges. Traditional approaches using Docker-in-Docker (DinD) or virtualized solutions suffer from resource overhead, complexity, and reliability issues. Developers need fast, stable, reproducible Kubernetes environments that integrate seamlessly with their existing Docker Desktop setup.

## Decision
Adopt **host-mode architecture** using Kind (Kubernetes in Docker) running directly on the host Docker daemon, eliminating Docker-in-Docker complexity. Kind was selected as the optimal technology for host-mode Kubernetes development due to its authentic K8s components and native host Docker integration.

## Rationale
1. **Stability**: Eliminates Docker Desktop hanging issues common with DinD approaches
2. **Performance**: 50% faster startup times compared to virtualized solutions
3. **Resource Efficiency**: Lower memory requirements (4GB vs 8GB typical)
4. **Simplicity**: Standard kubectl/kind workflow familiar to developers
5. **Integration**: Seamless integration with existing Docker Desktop installations
6. **Reliability**: Predictable behavior across Mac, Linux, and Windows WSL2

## Alternatives Considered

### 1. Docker-in-Docker (DinD)
- **Pros**: Complete isolation, container-native approach
- **Cons**: Stability issues, resource overhead, Docker Desktop conflicts, permission complexity
- **Decision**: Rejected due to reliability and resource concerns

### 2. Virtualized Solutions (minikube with VirtualBox/VMware)
- **Pros**: Strong isolation, production-like environment
- **Cons**: High resource usage, slow startup, additional software dependencies
- **Decision**: Rejected due to performance and complexity

### 3. Cloud-Based Development (EKS/GKE dev clusters)
- **Pros**: Production-like environment, unlimited resources
- **Cons**: Network latency, cost, internet dependency, complex setup
- **Decision**: Rejected for local development use case

### 4. Lightweight Solutions (k3s, k3d)
- **Pros**: Low resource usage, fast startup
- **Cons**: Non-standard Kubernetes distribution, limited ecosystem support
- **Decision**: Rejected due to compatibility concerns with standard Kubernetes

## Architecture Benefits

### Resource Efficiency
```
Host-Mode:     4GB RAM, 2 CPU cores (minimum)
DinD:          8GB RAM, 4 CPU cores (minimum)
Virtualized:   8GB RAM, 4 CPU cores (minimum)
```

### Startup Performance
```
Host-Mode:     < 2 minutes cluster creation
DinD:          3-5 minutes cluster creation
Virtualized:   5-10 minutes cluster creation
```

### Integration Model
```
Host Docker Daemon
├── Kind Cluster Container (single node)
│   ├── Control Plane + Worker (combined)
│   ├── Standard Kubernetes APIs
│   └── Direct port mapping to localhost
└── Developer Tools (kubectl, helm, flux)
```

## Consequences

**Positive:**
- Dramatic improvement in development velocity (faster iteration cycles)
- Lower barrier to entry (works with existing Docker Desktop)
- Reduced infrastructure complexity and maintenance overhead
- Better cross-platform consistency
- Standard Kubernetes tooling works without modification
- Ephemeral clusters become practical (fast create/destroy)

**Negative:**
- Less isolation than virtualized approaches
- Potential Docker Desktop version dependencies
- Limited to single-node clusters (acceptable for development)
- Host network sharing (managed through careful port allocation)

## Implementation Notes

### Network Architecture
- API Server: localhost:6443
- NodePort Services: localhost:8080 (mapped from 30080)
- Kubeconfig: ./data/kubeconfig/config
- Kind Network: 172.18.0.0/16 (managed by Docker)

### Dependency Management
```bash
# Required host tools
kind        # Cluster management
kubectl     # Kubernetes CLI
helm        # Package management
docker      # Container runtime (Docker Desktop)
```

### Cluster Lifecycle
```bash
make start  # < 2 minutes cluster creation
make status # Health validation
make restart # < 1 minute reset for development
make clean  # Complete cleanup
```

## Success Criteria
- Cluster creation < 2 minutes on modern hardware
- Memory usage ≤ 4GB for basic cluster
- Cross-platform compatibility (Mac, Linux, Windows WSL2)
- Docker Desktop integration without conflicts
- Standard kubectl commands work without modification
- 95%+ reliability for create/destroy cycles
