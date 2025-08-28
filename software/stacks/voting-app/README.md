# Voting App Stack

A complete example stack demonstrating HostK8s's end-to-end development workflow: from source code to production-like deployment using shared components and GitOps orchestration.

## Architecture

This stack demonstrates the **complete HostK8s value proposition**:
- **Source Code** → **Local Registry** → **GitOps Deployment** → **Shared Components**

### Components
- **Registry Component** - Local container registry for custom images
- **Redis Infrastructure** - Shared cache/queue for vote processing
- **Voting Application** - Multi-service app using shared infrastructure

### Application Services
- **Vote Service** (Python/Flask) - Web frontend for casting votes
- **Result Service** (Node.js/Express) - Real-time results with WebSocket
- **Worker Service** (Spring Boot/Java) - Background vote processor
- **PostgreSQL Database** - Persistent storage for vote results

## Complete Workflow

### 1. Start Cluster
```bash
export FLUX_ENABLED=true
make start
```

### 2. Deploy Stack (Registry + Redis + Voting Apps)
```bash
make up voting-app
```

**What happens automatically:**
- Registry component deploys first
- Redis infrastructure waits for registry readiness
- Voting applications deploy after infrastructure is ready
- All services connect via Kubernetes DNS

### 3. Build and Push Custom Images
```bash
make build src/sample-app
```

**What happens:**
- Builds vote, result, and worker services from source
- Pushes to local registry at `localhost:5000/hostk8s-*:latest`
- Images available for Kubernetes deployment

### 4. Applications Auto-Deploy
Since the stack is already deployed via GitOps, the applications will automatically pull the newly built images on restart or during deployment.

## Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Vote** | http://localhost:30080 | Cast votes between options |
| **Result** | http://localhost:30081 | View real-time results |
| **Redis Commander** | http://localhost:30500 | Monitor Redis data |
| **Registry** | http://localhost:30500 | Container registry management |

## Component Integration

### Service Discovery
Applications connect to shared components via Kubernetes DNS:
- **Redis**: `redis.redis-infrastructure.svc.cluster.local:6379`
- **Database**: `db.voting-app.svc.cluster.local:5432`

### Image Sources
```yaml
# Built from source code
vote: localhost:5000/hostk8s-vote:latest
result: localhost:5000/hostk8s-result:latest
worker: localhost:5000/hostk8s-worker:latest

# Standard images
postgres: postgres:15-alpine
redis: redis:7-alpine
```

## Dependency Flow

```
┌─────────────────┐
│     Registry    │ ← Deployed first
│   Component     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│      Redis      │ ← Waits for Registry
│  Infrastructure │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│   Voting App    │ ← Waits for Redis
│   Services      │
└─────────────────┘
```

## Development Workflow

### Iterative Development
```bash
# 1. Modify source code in src/sample-app/
# 2. Rebuild and push
make build src/sample-app

# 3. Restart deployments to pull new images
kubectl rollout restart deployment/vote -n voting-app
kubectl rollout restart deployment/result -n voting-app
kubectl rollout restart deployment/worker -n voting-app
```

### Local Development Against K8s Components
```bash
# Connect local development to shared Redis
cd src/sample-app/vote
export REDIS_HOST=localhost
kubectl port-forward -n redis-infrastructure svc/redis 6379:6379
python app.py  # Runs locally, uses K8s Redis
```

## Monitoring and Debugging

### Check Stack Status
```bash
make status
```

### View Component Health
```bash
# Redis infrastructure
kubectl get pods -n redis-infrastructure

# Voting applications
kubectl get pods -n voting-app

# Registry status
kubectl get pods -n registry
```

### Debug Service Connections
```bash
# Test Redis connectivity from voting app
kubectl exec -n voting-app deployment/vote -- \
  redis-cli -h redis.redis-infrastructure.svc.cluster.local ping

# Test database connectivity
kubectl exec -n voting-app deployment/result -- \
  pg_isready -h db.voting-app.svc.cluster.local -p 5432
```

### View Application Logs
```bash
kubectl logs -n voting-app deployment/vote -f
kubectl logs -n voting-app deployment/result -f
kubectl logs -n voting-app deployment/worker -f
```

## Stack Management

### Deploy Stack
```bash
make up voting-app
```

### Remove Stack
```bash
make down voting-app
```

### Sync Stack (Force GitOps Reconciliation)
```bash
make sync voting-app
```

## Troubleshooting

### Images Not Pulling
1. **Check registry accessibility**: `curl http://localhost:30500/v2/_catalog`
2. **Verify images exist**: `curl http://localhost:30500/v2/hostk8s-vote/tags/list`
3. **Rebuild if needed**: `make build src/sample-app`

### Services Can't Connect
1. **DNS resolution**: `kubectl exec -n voting-app deployment/vote -- nslookup redis.redis-infrastructure.svc.cluster.local`
2. **Port connectivity**: `kubectl exec -n voting-app deployment/vote -- telnet redis.redis-infrastructure.svc.cluster.local 6379`
3. **Check component health**: `kubectl get pods -n redis-infrastructure`

### Stack Won't Deploy
1. **Check Flux status**: `make status`
2. **View Flux logs**: `kubectl logs -n flux-system deployment/source-controller`
3. **Force reconciliation**: `make sync voting-app`

## What This Demonstrates

### HostK8s Value Proposition
✅ **Source-to-Deployment** - Complete workflow from `src/` to running applications
✅ **Shared Components** - Efficient resource usage via shared Redis/Registry
✅ **GitOps Orchestration** - Automated dependency management and health checks
✅ **Local Development** - Production-like environment on local machine
✅ **Container Integration** - Seamless build → registry → deploy workflow

### Real-World Patterns
- Multi-service application architecture
- Shared infrastructure components
- Service discovery via DNS
- Health checks and probes
- Resource limits and requests
- GitOps-based deployment automation

This voting app stack showcases how HostK8s transforms complex Kubernetes development into a streamlined, consistent workflow that scales from local development to production environments.
