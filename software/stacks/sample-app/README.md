# Sample App Stack

A complete voting application demonstrating HostK8s's component-based architecture and GitOps workflow. Shows how to build custom applications that use PostgreSQL and Redis components.

## Prerequisites

### Required Environment Configuration

The sample-app requires specific HostK8s addons. Configure your `.env` file:

```bash
# Required for sample-app
REGISTRY_ENABLED=true                  # Local container registry for built images
VAULT_ENABLED=true                     # Vault secret management for credentials
FLUX_ENABLED=true                      # GitOps deployment with Flux

# Optional optimizations
METALLB_ENABLED=true                   # Load balancer for services
INGRESS_ENABLED=true                   # NGINX ingress for web access
```

## Quick Start

### 1. Start Cluster
```bash
make start
```

This creates a Kind cluster with registry, Vault, and Flux ready.

### 2. Build Application Images
```bash
make build src/sample-app
```

**What this builds:**
- `hostk8s-vote:latest` - Python Flask voting frontend
- `hostk8s-result:latest` - Node.js Express results backend
- `hostk8s-worker:latest` - .NET Core background processor

Images are pushed to the local registry at `localhost:5002`.

### 3. Deploy Stack
```bash
make up sample-app
```

**What deploys:**
- PostgreSQL component (CloudNativePG operator + pgAdmin)
- Redis component (Redis server + Redis Commander)
- Voting application (vote + result + worker + database)

## Architecture

### Component-Based Design
```
sample-app stack
├── postgres component → PostgreSQL operator + pgAdmin UI
├── redis component → Redis server + Redis Commander UI
└── voting application → vote + result + worker + voting-db
```

### Service Communication
- **Vote service** → Redis (for vote queuing)
- **Worker service** → Redis ↔ PostgreSQL (processes votes)
- **Result service** → PostgreSQL (displays results)

### Data Flow
```
User votes → Vote service → Redis queue → Worker → PostgreSQL → Result service
```

## Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Voting** | http://localhost:8080/vote | Cast votes between options |
| **Results** | http://localhost:8080/result | View real-time vote results |
| **pgAdmin** | http://pgadmin.localhost:8080/ | PostgreSQL database management |
| **Redis Commander** | http://redis.localhost:8080/ | Redis data monitoring |

## Database Architecture

### PostgreSQL Cluster
- **Cluster**: `voting-db` in `postgres` namespace
- **Connection**: `voting-db-rw.postgres.svc.cluster.local:5432`
- **Database**: `voting` with `votes` table
- **Storage**: 5Gi persistent volume

### Redis Cache
- **Service**: `redis-master.redis.svc.cluster.local:6379`
- **Usage**: Vote queuing and session storage
- **Storage**: In-memory (development mode)

## Development Workflow

### Code Changes
```bash
# 1. Modify source code in src/sample-app/
# 2. Rebuild images
make build src/sample-app

# 3. Restart deployments to pull new images
kubectl rollout restart deployment/vote -n sample-app
kubectl rollout restart deployment/result -n sample-app
kubectl rollout restart deployment/worker -n sample-app
```

### Monitoring
```bash
# Check overall health
make status

# View application logs
kubectl logs -n sample-app deployment/vote -f
kubectl logs -n sample-app deployment/result -f
kubectl logs -n sample-app deployment/worker -f

# Check database
kubectl get cluster -n postgres voting-db

# Monitor Redis
kubectl get pods -n redis
```

## Troubleshooting

### Common Issues

**Applications not starting:**
```bash
# Check if images were built and pushed
curl http://localhost:5002/v2/_catalog
curl http://localhost:5002/v2/hostk8s-vote/tags/list

# Rebuild if missing
make build src/sample-app
```

**Database connection issues:**
```bash
# Check PostgreSQL cluster status
kubectl get cluster -n postgres voting-db
kubectl describe cluster -n postgres voting-db

# Test database connectivity
kubectl exec -n sample-app deployment/result -- \
  pg_isready -h voting-db-rw.postgres.svc.cluster.local -p 5432
```

**Redis connection issues:**
```bash
# Check Redis status
kubectl get pods -n redis

# Test Redis connectivity
kubectl exec -n sample-app deployment/worker -- \
  redis-cli -h redis-master.redis.svc.cluster.local ping
```

### Stack Management

```bash
# Redeploy entire stack
make down sample-app
make up sample-app

# Force GitOps sync
make sync sample-app

# View Flux reconciliation
kubectl get kustomizations -n flux-system
```

## What This Demonstrates

### HostK8s Patterns
✅ **Component Composition** - Reusable postgres + redis components
✅ **Source-to-Deployment** - Complete workflow from source code to running apps
✅ **GitOps Automation** - Infrastructure and applications managed declaratively
✅ **Local Development** - Production-like environment on your machine
✅ **Secret Management** - Automatic credential generation and injection
✅ **Persistent Storage** - Database survives cluster restarts

### Real-World Architecture
- Multi-service application with shared infrastructure
- Database persistence and management
- Background job processing
- Real-time web interfaces
- Container image management
- Component-based system design

The sample-app validates that HostK8s provides a complete, production-ready development environment that scales from local development to cloud deployment.
