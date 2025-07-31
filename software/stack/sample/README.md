# Sample GitOps Stamp

This demonstrates the **Component/Application separation pattern** for GitOps deployments using Flux.

## Architecture

```
sample/
├── kustomization.yaml           # Main orchestrator
├── components/                  # Infrastructure layer
│   ├── kustomization.yaml
│   ├── ingress-nginx/          # Ingress controller
│   │   ├── namespace.yaml      #   Dedicated namespace
│   │   ├── source.yaml         #   HelmRepository
│   │   └── release.yaml        #   HelmRelease
│   └── database/               # PostgreSQL database
│       ├── namespace.yaml      #   Dedicated namespace
│       ├── source.yaml         #   HelmRepository (bitnami)
│       └── release.yaml        #   HelmRelease
└── applications/               # Business logic layer
    ├── kustomization.yaml
    ├── api/                    # Backend API service
    │   ├── namespace.yaml      #   sample-api namespace
    │   ├── deployment.yaml     #   API deployment + config
    │   ├── service.yaml        #   ClusterIP service
    │   └── ingress.yaml        #   /api path routing
    └── website/                # Frontend web service
        ├── namespace.yaml      #   sample-website namespace
        ├── deployment.yaml     #   Website deployment + config
        ├── service.yaml        #   ClusterIP service
        └── ingress.yaml        #   / path routing
```

## Components (Infrastructure)

### Ingress-NGINX Controller
- **Purpose**: HTTP routing and load balancing
- **Deployment**: HelmRelease from kubernetes.github.io/ingress-nginx
- **Configuration**: NodePort 30080/30443 for Kind compatibility
- **Namespace**: `ingress-nginx`

### PostgreSQL Database
- **Purpose**: Data persistence layer
- **Deployment**: HelmRelease from charts.bitnami.com/bitnami
- **Configuration**: Development settings (no persistence)
- **Namespace**: `database`
- **Credentials**: postgres/postgres, appuser/apppass

## Applications (Business Logic)

### Sample API
- **Purpose**: Backend service demonstrating database connectivity
- **Namespace**: `sample-api`
- **Access**: http://localhost:8080/api
- **Database**: Connects to `postgresql.database.svc.cluster.local:5432`

### Sample Website
- **Purpose**: Frontend interface demonstrating the stamp pattern
- **Namespace**: `sample-website`
- **Access**: http://localhost:8080/
- **API**: Communicates with `sample-api.sample-api.svc.cluster.local`

## Deployment

### Option 1: Direct Kustomize
```bash
kubectl apply -k software/stamp/sample/
```

### Option 2: Via Flux GitOps
```bash
# Update flux kustomization to point to sample stamp
kubectl patch kustomization osdu-ci-stamp -n flux-system --type merge -p '{"spec":{"path":"./software/stamp/sample"}}'
```

## Testing

```bash
# Check components
kubectl get helmrelease -n flux-system
kubectl get pods -n ingress-nginx
kubectl get pods -n database

# Check applications
kubectl get pods -n sample-api
kubectl get pods -n sample-website

# Test access
curl http://localhost:8080/
curl http://localhost:8080/api

# Monitor GitOps
flux get sources helm
flux get helmreleases
flux logs --follow
```

## Key Benefits

1. **Separation of Concerns**: Infrastructure vs. business logic
2. **Helm Integration**: Components use proven charts
3. **Dependency Management**: Components deploy before applications
4. **Service Discovery**: Applications communicate via Kubernetes DNS
5. **GitOps Ready**: Fully declarative via Flux
6. **Development Friendly**: Works with manual `kubectl apply` too

This pattern scales from simple demos to complex production systems!
