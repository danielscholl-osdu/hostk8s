# Redis Infrastructure Component

Shared Redis infrastructure component providing caching and data storage services with web-based management interface for HostK8s applications.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|----------|-------------|-----------|----------------|--------------|
| redis | 1 | 50m | 200m | 128Mi | 256Mi |
| redis-commander | 1 | 25m | 100m | 64Mi | 128Mi |
| **Total Component Resources** | | **75m** | **300m** | **192Mi** | **384Mi** |

## Services & Access

| Service | Endpoint | Port | Purpose |
|---------|----------|------|---------|
| Redis Server | `redis.redis-infrastructure.svc.cluster.local` | 6379 | Application data store |
| Management UI | `localhost` | 30081 | Web interface for Redis management |

### Authentication
- **Redis Password**: `devpassword` (development only)
- **Management UI**: Login `admin/admin`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                Redis Infrastructure Component               │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │                 │    │                 │                │
│  │   Redis Server  │◄──►│ Redis Commander │                │
│  │  (data store)   │    │  (management)   │                │
│  │                 │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│    ClusterIP :6379         NodePort :30081                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Persistent Storage (1GB)                  ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Integration

Stacks reference this component in their `stack.yaml`:

```yaml
- name: component-redis-infrastructure
  namespace: flux-system
  path: ./software/components/redis-infrastructure
```

Applications connect using the internal service:

```yaml
env:
- name: REDIS_URL
  value: "redis://:devpassword@redis.redis-infrastructure.svc.cluster.local:6379"
```

## Storage

| Resource | Size | Purpose | Retention |
|----------|------|---------|-----------|
| Persistent Volume | 1GB | Redis data persistence | Survives pod restarts and updates |
| Snapshot Policy | Automatic | Data durability | Configured for development workloads |

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `redis-infrastructure` |
| Configuration | Development-optimized with persistent storage |
| Health Check | Redis ping command and HTTP health checks |
| Key Features | In-memory data store, web management UI, data persistence |

### Basic Operations
```bash
# Check component status
kubectl get pods -n redis-infrastructure
kubectl get pvc -n redis-infrastructure

# Test Redis connectivity
kubectl exec -n redis-infrastructure deployment/redis -- redis-cli -a devpassword ping

# Access management UI
open http://localhost:30081  # Login: admin/admin

# View Redis logs
kubectl logs -n redis-infrastructure deployment/redis
```
