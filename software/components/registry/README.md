# Container Registry Component

Shared Docker registry component providing local container image storage and distribution for HostK8s development workflows with integrated build system support.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|----------|-------------|-----------|----------------|--------------|
| docker-registry | 1 | 100m | 200m | 128Mi | 256Mi |
| **Total Component Resources** | | **100m** | **200m** | **128Mi** | **256Mi** |

## Services & Access

| Service | Endpoint | Port | Purpose |
|---------|----------|------|---------|
| Registry API | `registry.registry.svc.cluster.local` | 5000 | Internal image push/pull |
| External Registry | `localhost` | 5000 | Development image operations |
| Registry HTTP | `localhost` | 30500 | External HTTP access and API |

### API Endpoints
- **Health Check**: `localhost:30500/v2/`
- **Image Catalog**: `localhost:30500/v2/_catalog`
- **Image Tags**: `localhost:30500/v2/{name}/tags/list`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Container Registry Component               │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │                 │    │                 │                │
│  │ Docker Registry │◄──►│  Registry API   │                │
│  │   (registry:2)  │    │    (REST)       │                │
│  │                 │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│    ClusterIP :5000         NodePort :30500                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │           Persistent Storage (10GB)                     ││
│  │         /mnt/local-storage/registry                     ││
│  └─────────────────────────────────────────────────────────┘│
│                                                             │
│  Kind cluster integration: localhost:5000 → internal       │
└─────────────────────────────────────────────────────────────┘
```

## Integration

Stacks reference this component in their `stack.yaml`:

```yaml
- name: component-registry
  namespace: flux-system
  path: ./software/components/registry
```

### Build System Integration
```bash
# HostK8s build workflow
make build src/my-app  # Automatically pushes to localhost:5000/my-app:latest
```

### Application Image References
```yaml
# Kubernetes deployments
spec:
  containers:
  - name: api
    image: localhost:5000/my-app:latest  # Kind resolves to internal registry
```

### Direct Registry Operations
```bash
# Push images
docker tag my-app:latest localhost:5000/my-app:latest
docker push localhost:5000/my-app:latest

# Browse content
curl http://localhost:30500/v2/_catalog
curl http://localhost:30500/v2/my-app/tags/list
```

## Storage

| Resource | Size | Purpose | Retention |
|----------|------|---------|-----------|
| Persistent Volume | 10GB | Container image storage | Survives pod restarts and cluster rebuilds |
| Host Mount | `/mnt/local-storage/registry` | Storage backend | Manual cleanup required |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `registry` |
| Configuration | Development-optimized with Kind cluster integration |
| Health Check | HTTP endpoint `/v2/` |
| Key Features | Container image storage, build system integration, no authentication |

### Basic Operations
```bash
# Check component status
kubectl get pods -n registry
kubectl get pvc -n registry

# Test registry health
curl http://localhost:30500/v2/

# List stored images
curl http://localhost:30500/v2/_catalog

# Push test image
docker tag hello-world localhost:5000/test:latest
docker push localhost:5000/test:latest

# Verify storage
kubectl exec -n registry deployment/registry -- ls -la /var/lib/registry
```
