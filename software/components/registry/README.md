# Container Registry Component

Shared Docker registry component providing local container image storage and distribution for HostK8s development workflows.

## Services

- **Docker Registry v2.7**: Local container image storage with persistent volumes
- **Registry API**: REST API for image management and catalog browsing

## Access

- **Applications**: `registry.registry.svc.cluster.local:5000`
- **External**: http://localhost:30500 (development access)
- **Registry Catalog**: http://localhost:30500/v2/_catalog
- **Image Manifest**: http://localhost:30500/v2/{name}/manifests/{tag}

## Architecture

```
┌─────────────────────────────────────────────┐
│           Container Registry                │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │           Docker Registry               ││
│  │         (registry:2.7)                 ││
│  │                                         ││
│  │  Internal: ClusterIP:5000              ││
│  │  External: NodePort:30500              ││
│  │                                         ││
│  │  ┌─────────────────────────────────┐    ││
│  │  │     Persistent Storage          │    ││
│  │  │        (10GB)                   │    ││
│  │  │   /mnt/local-storage/registry   │    ││
│  │  └─────────────────────────────────┘    ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

## Usage in Build System

HostK8s automatically integrates with the registry for local development:

```bash
# Build and push application to registry
make build src/sample-app

# Registry automatically receives images tagged as:
# localhost:5000/sample-app-vote:latest
# localhost:5000/sample-app-result:latest
# localhost:5000/sample-app-worker:latest
```

## Usage from Applications

Applications can reference locally built images:

```yaml
# Kubernetes Deployment
spec:
  containers:
  - name: api
    image: localhost:5000/my-app:latest
    # Kind clusters automatically resolve localhost:5000 to internal registry
```

```yaml
# Docker Compose (for local builds)
services:
  api:
    image: localhost:5000/my-app:latest
    build: .
```

## Direct Registry Operations

### Push Existing Images
```bash
# Tag existing image for local registry
docker tag my-app:latest localhost:5000/my-app:latest

# Push to registry
docker push localhost:5000/my-app:latest
```

### Pull Images
```bash
# Pull from local registry
docker pull localhost:5000/my-app:latest
```

### Browse Registry Content
```bash
# List all repositories
curl http://localhost:30500/v2/_catalog

# List tags for a repository
curl http://localhost:30500/v2/my-app/tags/list

# Get image manifest
curl http://localhost:30500/v2/my-app/manifests/latest
```

## Storage

- **Persistent Volume**: 10GB storage for container images
- **Location**: `/mnt/local-storage/registry` on host
- **Retention**: Images survive pod restarts and cluster rebuilds
- **Policy**: Manual cleanup (images persist until explicitly removed)

## Kind Integration

Kind clusters are pre-configured to work with the local registry:

- **Automatic Resolution**: `localhost:5000` resolves to internal registry service
- **No Authentication**: Registry runs in development mode (no auth required)
- **Containerd Config**: Kind automatically routes localhost:5000 to registry.registry.svc.cluster.local:5000

## Configuration

Registry runs with development-optimized settings:

- **Storage Driver**: Filesystem backend with persistent volume
- **Health Checks**: HTTP health endpoint on `/v2/`
- **Resource Limits**: 256Mi memory, 200m CPU
- **Network**: HTTP only (no TLS for development)

## Commands

```bash
# Deploy component
kubectl apply -k software/components/registry/

# Check component status
kubectl get all -n registry

# View registry logs
kubectl logs -n registry deployment/registry

# Check registry health
curl http://localhost:30500/v2/

# List stored images
curl http://localhost:30500/v2/_catalog | jq .

# Remove component
kubectl delete -k software/components/registry/

# Clean up images (requires manual registry API calls)
# Note: Registry doesn't provide built-in cleanup via API
```

## Integration with HostK8s Build System

The registry enables HostK8s's source code build system:

1. **Build**: `make build src/my-app` builds containers using Docker Compose
2. **Tag**: Images automatically tagged with `localhost:5000/` prefix
3. **Push**: Images pushed to local registry
4. **Deploy**: Kubernetes manifests reference `localhost:5000/` images
5. **Run**: Kind resolves `localhost:5000` to internal registry service

## Troubleshooting

### Registry Not Accessible
```bash
# Check registry pod status
kubectl get pods -n registry

# Check service endpoints
kubectl get svc -n registry

# Test internal connectivity
kubectl run test --image=busybox --rm -it -- nslookup registry.registry.svc.cluster.local
```

### Images Not Persisting
```bash
# Check persistent volume
kubectl get pv registry-data-pv

# Check persistent volume claim
kubectl get pvc -n registry

# Verify volume mount
kubectl describe pod -n registry
```

### Build Integration Issues
```bash
# Verify Kind registry configuration
docker exec -it hostk8s-control-plane cat /etc/containerd/config.toml | grep localhost

# Test direct push
docker tag hello-world localhost:5000/test
docker push localhost:5000/test

# Verify image stored
curl http://localhost:30500/v2/_catalog
```

This registry component is essential for local development workflows, enabling rapid iteration on containerized applications within the HostK8s platform.
