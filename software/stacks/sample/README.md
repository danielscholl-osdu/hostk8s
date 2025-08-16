# Sample GitOps Stack

This demonstrates the **Component/Application separation pattern** for GitOps deployments using Flux.

## Architecture

```
sample/
├── kustomization.yaml          # Main orchestrator
├── repository.yaml             # GitRepository source
├── stack.yaml                  # Infrastructure components via Flux
├── ingress-nginx/              # NGINX Ingress Controller
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── source.yaml             # HelmRepository
│   └── release.yaml            # HelmRelease
└── app/                        # Application layer
    ├── kustomization.yaml
    ├── namespace.yaml          # sample namespace
    ├── api/                    # Backend API service
    │   ├── deployment.yaml     #   API with file storage
    │   ├── service.yaml        #   ClusterIP service
    │   ├── ingress.yaml        #   /api path routing
    │   ├── certificate.yaml    #   TLS certificate
    │   └── storage.yaml        #   Persistent volume claim
    └── web/                    # Frontend web service
        ├── deployment.yaml     #   Website deployment
        ├── service.yaml        #   ClusterIP service
        ├── ingress.yaml        #   / path routing
        ├── certificate.yaml    #   TLS certificate
        └── config-map.yaml     #   Website content
```

## Components (Infrastructure)

Deployed as Flux Kustomizations in `stack.yaml` with proper dependency ordering:

### Core Infrastructure
- **Metrics Server**: Resource monitoring capabilities (`kube-system`)
- **Cert-Manager**: TLS certificate management (`cert-manager`)
- **Root CA**: Self-signed certificate authority for development
- **Certificate Issuer**: CA issuer for automatic certificate generation

### Ingress-NGINX Controller
- **Purpose**: HTTP routing and load balancing
- **Deployment**: HelmRelease from kubernetes.github.io/ingress-nginx
- **Configuration**: NodePort 30080/30443 for Kind compatibility
- **Namespace**: `ingress-nginx`
- **Dependencies**: Requires cert-manager for TLS certificates

## Applications (Business Logic)

### Sample API
- **Purpose**: Backend service demonstrating file storage and persistence
- **Runtime**: Node.js Express server with embedded code
- **Namespace**: `sample`
- **Access**: http://localhost:8080/api
- **Storage**: Persistent volume at `/app/storage` for file operations
- **Endpoints**:
  - `GET /` - API service information page
  - `GET /health` - Health check
  - `POST /storage/test` - Create test file
  - `GET /storage/test` - Read test file
  - `DELETE /storage/test` - Delete test file

### Sample Website
- **Purpose**: Frontend interface demonstrating the stack pattern
- **Runtime**: NGINX serving static content from ConfigMap
- **Namespace**: `sample`
- **Access**: http://localhost:8080/
- **API Integration**: Communicates with `sample-api.sample.svc.cluster.local`

## Deployment

### Option 1: Via Make Commands (Recommended)
```bash
export FLUX_ENABLED=true
make start                      # Start cluster with Flux
make up sample                  # Deploy sample stack via GitOps
make status                     # Monitor deployment progress
```

### Option 2: Direct Kustomize
```bash
kubectl apply -k software/stacks/sample/
```

### Option 3: Via Flux GitOps
```bash
# Deploy via Flux bootstrap pattern
kubectl apply -f software/stacks/bootstrap.yaml
```

## Testing

```bash
# Check infrastructure components
kubectl get kustomization -n flux-system
kubectl get pods -n cert-manager
kubectl get pods -n ingress-nginx

# Check applications
kubectl get pods -n sample
kubectl get pvc -n sample

# Test endpoints
curl http://localhost:8080/           # Website
curl http://localhost:8080/api        # API info page
curl http://localhost:8080/api/health # Health check

# Test storage functionality
curl -X POST http://localhost:8080/api/storage/test    # Create file
curl http://localhost:8080/api/storage/test            # Read file
curl -X DELETE http://localhost:8080/api/storage/test  # Delete file

# Monitor GitOps
flux get sources git
flux get kustomizations
flux logs --follow
```

## Key Benefits

1. **Separation of Concerns**: Infrastructure components vs. business applications
2. **Certificate Management**: Automatic TLS certificates via cert-manager
3. **Dependency Management**: Proper deployment ordering via Flux dependencies
4. **Persistent Storage**: File-based persistence instead of database complexity
5. **Service Discovery**: Applications communicate via Kubernetes DNS
6. **GitOps Ready**: Fully declarative deployment via Flux
7. **Development Friendly**: Works with both GitOps and direct kubectl
8. **Resource Efficiency**: Lightweight Node.js API with minimal resource usage

This pattern demonstrates how to build production-ready environments without database overhead!
