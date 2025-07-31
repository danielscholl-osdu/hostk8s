# Extensions App - Multi-Service Application

A comprehensive 3-tier application demonstrating service-to-service communication patterns and microservices architecture.

## Features
- 3-tier architecture (Frontend → API → Database)
- Service-to-service communication via Kubernetes DNS
- Health checks and readiness probes
- Resource management and scaling examples
- Interactive web interface with testing capabilities

## Architecture

```
Frontend (nginx) → API (nginx) → Database (postgresql)
     ↓               ↓              ↓
 Port 30080      ClusterIP      ClusterIP
(localhost:8080)
```

## Services

### 🎨 Frontend Service (2 replicas)
- **Purpose**: User interface and API communication
- **Image**: mcr.microsoft.com/azurelinux/base/nginx with custom HTML
- **Access**: http://localhost:8080 (NodePort 30080)
- **Environment**: `API_URL=http://api`

### 🔌 API Service (2 replicas)
- **Purpose**: Business logic and database communication
- **Image**: mcr.microsoft.com/azurelinux/base/nginx (placeholder for real API)
- **Internal Access**: `http://api` (ClusterIP)
- **Environment**: `DATABASE_URL=postgresql://appuser:apppass@database:5432/appdb`
- **Health Checks**: `/health` and `/ready` endpoints

### 🗄️ Database Service (1 replica)
- **Purpose**: Data persistence
- **Image**: mcr.microsoft.com/azurelinux/base/postgres:15
- **Internal Access**: `database:5432` (ClusterIP)
- **Credentials**: `appuser/apppass`, database: `appdb`

## Deploy

```bash
make deploy extensions/sample
# or
kubectl apply -f software/apps/extensions/sample/app.yaml
```

## Access
- **URL**: http://localhost:8080
- **Service Type**: NodePort (30080)
- **Interactive Interface**: Test buttons for API and database connectivity

## Use Case
Perfect for:
- Understanding microservices communication patterns
- Testing Kubernetes service discovery
- Learning 3-tier application architecture
- Prototyping real microservices deployments
- Demonstrating horizontal pod scaling

## Testing Service Communication

```bash
# Test frontend → API communication
kubectl exec -it deployment/frontend -- wget -qO- http://api

# Test API → database connectivity
kubectl exec -it deployment/api -- nc -zv database 5432

# View all pod IPs and communication paths
kubectl get pods -o wide -l 'tier in (frontend,api,database)'

# Check logs
kubectl logs deployment/api
kubectl logs deployment/database
```

## Scaling Examples

```bash
# Scale API service
kubectl scale deployment api --replicas=3

# Scale frontend
kubectl scale deployment frontend --replicas=1

# View updated deployment
kubectl get pods -l tier=api
```

## Service Discovery

Demonstrates Kubernetes DNS-based service discovery:
- Frontend finds API via: `http://api` (resolves to `api.default.svc.cluster.local`)
- API finds database via: `database:5432` (resolves to `database.default.svc.cluster.local`)

## Requirements
- Basic cluster (no special add-ons required)
- Uses standard NodePort for external access

## Cleanup

```bash
kubectl delete -f software/apps/extensions/sample/app.yaml
# or
kubectl delete deployment,service,configmap -l hostk8s.app=sample
```
