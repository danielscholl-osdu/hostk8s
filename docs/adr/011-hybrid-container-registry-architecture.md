# ADR-011: Hybrid Container Registry Architecture

## Status
**Accepted** - 2025-08-29

## Context
Local Kubernetes development environments require container registries for building, storing, and deploying custom application images. Traditional approaches use either pure Kubernetes deployments or external registry services, each with significant limitations for development workflows.

**Development Registry Requirements:**
- Fast, reliable container image storage and retrieval
- Integration with Kind cluster containerd for seamless image pulling
- Web UI for registry browsing and management
- Persistence across cluster restarts
- Minimal resource overhead
- Cross-origin request handling for web UI functionality

**Registry Deployment Challenge:**
Pure Kubernetes registry deployments face containerd integration complexity, persistent volume management overhead, and cross-origin request handling issues. External registry services introduce network dependencies and authentication complexity unsuitable for local development.

## Decision
Adopt a **hybrid container registry architecture** combining Docker container deployment for the registry API with Kubernetes deployment for the web UI, connected through ingress proxy configuration.

**Architecture Components:**
- **Registry API**: Docker container (`registry:2`) running on host Docker daemon
- **Registry UI**: Kubernetes deployment in `hostk8s` namespace
- **Integration**: NGINX ingress handles both UI requests and API proxying
- **Storage**: Host-mounted persistent storage for registry data

## Rationale

### Reliability and Performance
1. **Container-Native Registry** - Docker registry runs natively on host Docker daemon, eliminating Kubernetes orchestration overhead
2. **Direct Containerd Integration** - Kind nodes configured with containerd hosts.toml for seamless registry access
3. **Persistent Storage** - Host directory mounting survives cluster recreate/restart operations
4. **Network Simplicity** - Docker container connects directly to Kind network for internal communication

### Web UI Integration Benefits
1. **CORS Resolution** - Ingress proxy eliminates cross-origin requests by serving UI and API from same origin
2. **Ingress Native** - Web UI leverages existing NGINX ingress infrastructure
3. **Kubernetes Management** - UI deployment follows standard Kubernetes patterns for scaling and updates
4. **Developer Experience** - Single `localhost:8080/registry/` URL provides complete registry functionality

### Operational Advantages
1. **Startup Reliability** - Docker container starts independently of Kubernetes cluster state
2. **Resource Efficiency** - Registry API runs outside cluster resource constraints
3. **Debug Accessibility** - Docker container accessible via standard Docker commands
4. **Hybrid Benefits** - Combines container reliability with Kubernetes UI management

## Alternatives Considered

### 1. Pure Kubernetes Deployment
- **Pros**: Consistent with platform patterns, Kubernetes-native resource management, standard deployment workflow
- **Cons**: Containerd configuration complexity, persistent volume overhead, CORS handling issues, startup dependencies
- **Decision**: Rejected due to operational complexity and reliability concerns

### 2. External Registry Service (Docker Hub, etc.)
- **Pros**: Zero operational overhead, unlimited storage, production-like environment
- **Cons**: Network dependency, authentication complexity, image privacy concerns, development velocity impact
- **Decision**: Rejected for local development isolation requirements

### 3. Docker Compose Registry
- **Pros**: Simple deployment, familiar Docker patterns, easy configuration
- **Cons**: Outside Kubernetes ecosystem, no UI integration, manual network configuration, lifecycle management complexity
- **Decision**: Rejected due to platform integration requirements

### 4. Registry + UI in Same Pod
- **Pros**: Single deployment unit, shared storage, simplified networking
- **Cons**: Container coupling, resource contention, restart coupling, debugging complexity
- **Decision**: Rejected due to separation of concerns principle

## Architecture Benefits

### Network Integration Model
```
Host Docker Network (172.18.0.0/16)
├── Docker Registry Container (hostk8s-registry:5000)
│   ├── Host Port Binding: 127.0.0.1:5002
│   ├── Kind Network Access: hostk8s-registry:5000
│   └── Storage: ./data/storage/registry
└── Kind Cluster
    ├── Containerd Configuration: /etc/containerd/certs.d/localhost:5000/hosts.toml
    ├── Registry UI Pod: registry-ui deployment
    └── NGINX Ingress: localhost:8080/registry/ + /v2/ API proxy
```

### CORS Resolution Strategy
```yaml
# NGINX Ingress Configuration
- path: /registry/
  pathType: Prefix
  backend:
    service:
      name: registry-ui
      port:
        number: 80
- path: /v2/          # API proxy path
  pathType: Prefix
  backend:
    service:
      name: registry-api  # Service pointing to Docker container
      port:
        number: 5000
```

### Containerd Integration
```toml
# /etc/containerd/certs.d/localhost:5000/hosts.toml
server = "http://hostk8s-registry:5000"

[host."http://hostk8s-registry:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
```

## Consequences

**Positive:**
- Eliminates CORS issues through same-origin API access
- Provides reliable, fast registry API through native Docker deployment
- Maintains Kubernetes-native UI management and ingress integration
- Survives cluster restarts without data loss
- Enables container-native image building and deployment workflows
- Simplifies debugging through standard Docker container access

**Negative:**
- Architectural complexity through hybrid deployment pattern
- Requires Docker container lifecycle management outside Kubernetes
- Additional network configuration for Kind node containerd integration
- Documentation overhead for explaining hybrid architecture
- Platform-specific setup requirements (Docker + Kubernetes coordination)

## Implementation Notes

### Container Startup Sequence
```bash
# Registry container creation
docker run -d --restart=always \
  -p "127.0.0.1:5002:5000" \
  -v "${registry_data_dir}:/var/lib/registry" \
  --name "hostk8s-registry" registry:2

# Kind network connection
docker network connect "kind" "hostk8s-registry"
```

### Kind Node Configuration
```bash
# Per-node containerd configuration
for node in $(kind get nodes --name "${CLUSTER_NAME}"); do
    docker exec "$node" mkdir -p "/etc/containerd/certs.d/localhost:5000"
    # Configure hosts.toml for registry access
done
```

### Kubernetes UI Integration
```yaml
# registry-ui.yaml deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-ui
  namespace: hostk8s
spec:
  template:
    spec:
      containers:
      - name: ui
        image: joxit/docker-registry-ui:static
        env:
        - name: REGISTRY_URL
          value: "http://localhost:8080/v2"  # Same-origin API access
```

## Success Criteria
- Registry API accessible from both host (localhost:5002) and cluster (hostk8s-registry:5000)
- Web UI loads without CORS errors at localhost:8080/registry/
- Container images push/pull successfully from development workflows
- Registry data persists across cluster restart operations
- Kind cluster nodes pull images seamlessly from local registry
- Docker container and Kubernetes UI deployments operate independently
