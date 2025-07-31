# Registry Demo - Deployment

This directory contains **deployment manifests** for the Registry Demo application. The application demonstrates pulling custom images from the local registry component.

## Architecture

- **Source Code**: `src/registry-demo/` (build and push from there)
- **Deployment Manifests**: `software/apps/sample/registry-demo/` (this directory)
- **Registry Component**: `software/components/registry/` (shared infrastructure)

This separation follows enterprise patterns where deployment manifests reference pre-built images from container registries.

## Prerequisites

### 1. Registry Component Deployed
```bash
make up sample
curl http://localhost:30500/v2/  # Verify registry accessibility
```

### 2. Application Image Built and Pushed
```bash
make build src/registry-demo
```

## Deployment

### Deploy Application
```bash
make deploy sample/registry-demo
```

### Verify Deployment
```bash
make status
# Look for "📱 registry-demo" in Manual Deployed Apps section
```

## Access Points

### NodePort (Always Available)
- **URL**: http://localhost:30510
- **Port**: 30510 mapped to pod port 80

### Ingress (When INGRESS_ENABLED=true)
- **URL**: http://localhost:8080/registry-demo
- **Path**: `/registry-demo` routed to service

## Application Details

### Kubernetes Resources
- **Deployment**: 2 replicas with resource limits
- **Service**: NodePort service exposing port 80
- **Ingress**: Optional ingress with path-based routing

### Image Configuration
- **Image**: `localhost:5000/registry-demo:latest`
- **Pull Policy**: Always (for development iteration)
- **Registry Resolution**: Kind resolves `localhost:5000` to internal registry service

### Resource Limits
- **Memory**: 32Mi request / 64Mi limit
- **CPU**: 25m request / 50m limit

## Registry Integration

### Image Pull Process
1. **Deployment References**: `localhost:5000/registry-demo:latest`
2. **Containerd Resolution**: Kind resolves to `registry.registry.svc.cluster.local:5000`
3. **Internal Pull**: Pods pull from internal registry service (no external network)
4. **Caching**: Images cached in Kind node for subsequent deployments

### Registry Architecture
- **Namespace**: `registry` (shared component)
- **Internal Service**: `registry.registry.svc.cluster.local:5000`
- **External Access**: NodePort 30500 (for push operations)
- **Storage**: 10Gi persistent volume
- **Management**: Deployed via GitOps stamp

## Development Workflow

### 1. Modify Source Code
```bash
cd src/registry-demo
# Edit Dockerfile, index.html, etc.
```

### 2. Build and Push
```bash
make build src/registry-demo
```

### 3. Redeploy Application
```bash
# Force pod restart to pull latest image
kubectl rollout restart deployment/registry-demo

# Or delete and redeploy
kubectl delete -f app.yaml
make deploy sample/registry-demo
```

### 4. Verify Changes
```bash
curl http://localhost:30510
```

## Validation Commands

### Application Status
```bash
# Check pod status
kubectl get pods -l app=registry-demo

# Check service endpoints
kubectl get endpoints registry-demo

# View application logs
kubectl logs -l app=registry-demo
```

### Image Verification
```bash
# Verify image source in pod
kubectl describe pod -l app=registry-demo | grep -A5 "Image:"

# Check registry contains image
curl http://localhost:30500/v2/registry-demo/tags/list
```

### Access Testing
```bash
# Test NodePort access
curl http://localhost:30510

# Test ingress access (if enabled)
curl http://localhost:8080/registry-demo
```

## Troubleshooting

### ImagePullBackOff Errors
**Problem**: Pods cannot pull `localhost:5000/registry-demo:latest`

**Solutions**:
1. **Verify image exists**: `curl http://localhost:30500/v2/registry-demo/tags/list`
2. **Check registry health**: `curl http://localhost:30500/v2/`
3. **Rebuild image**: `make build src/registry-demo`
4. **Restart pods**: `kubectl rollout restart deployment/registry-demo`

### Service Not Accessible
**Problem**: Cannot access application via NodePort or Ingress

**Solutions**:
1. **Check service**: `kubectl get svc registry-demo`
2. **Check endpoints**: `kubectl get endpoints registry-demo`
3. **Check pod status**: `kubectl get pods -l app=registry-demo`
4. **Check ingress** (if applicable): `kubectl get ingress registry-demo`

### Registry Component Missing
**Problem**: Registry not available for image pulls

**Solutions**:
1. **Deploy registry**: `make up sample` (includes registry component)
2. **Check registry status**: `kubectl get pods -n registry`
3. **Verify registry access**: `curl http://localhost:30500/v2/`

## Educational Value

### Deployment Patterns
- **Registry Integration**: How Kubernetes pulls from local registries
- **Resource Management**: CPU/memory limits and requests
- **Service Discovery**: NodePort and Ingress access patterns
- **Pod Lifecycle**: Deployment, scaling, and restart patterns

### Enterprise Alignment
- **Separation of Concerns**: Source code vs deployment manifests
- **Registry Workflows**: Pre-built images deployed from registries
- **Platform Services**: Shared components (registry) supporting applications
- **GitOps Patterns**: Deployment manifests in version control

## Multi-Environment Support

These manifests can be extended for different environments:

### Development
```yaml
# Current configuration - uses localhost:5000 registry
image: localhost:5000/registry-demo:latest
```

### Staging/Production
```yaml
# Would reference external registry
image: mycompany.azurecr.io/registry-demo:v1.2.3
```

The deployment patterns remain consistent across environments, only the image source changes.
