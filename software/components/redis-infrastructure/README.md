# Redis Infrastructure Component

Shared Redis infrastructure component providing caching and data storage services for HostK8s applications.

## Services

- **Redis Server**: High-performance in-memory data store with persistence
- **Redis Commander**: Web-based management interface for Redis

## Access

- **Applications**: `redis.redis-infrastructure.svc.cluster.local:6379`
- **Management UI**: http://localhost:30081 (admin/admin)
- **Password**: `devpassword` (development only)

## Architecture

```
┌─────────────────────────────────────────────┐
│           Redis Infrastructure              │
│                                             │
│  ┌─────────────┐      ┌─────────────────┐  │
│  │    Redis    │      │     Redis       │  │
│  │   Server    │◄────►│   Commander     │  │
│  │  (Internal) │      │   (External)    │  │
│  └─────────────┘      └─────────────────┘  │
│         │                       │          │
│    ClusterIP                NodePort       │
│     :6379                   :30081         │
└─────────────────────────────────────────────┘
```

## Usage from Applications

Applications can connect to Redis using the internal service:

```yaml
env:
- name: REDIS_URL
  value: "redis://:devpassword@redis.redis-infrastructure.svc.cluster.local:6379"
```

## Storage

- **Persistent Volume**: 1GB storage for Redis data
- **Persistence**: Automatic snapshots for data durability
- **Retention**: Data survives pod restarts and updates

## Monitoring

- Health checks on both Redis server and Commander
- Resource limits prevent excessive resource usage
- Management UI provides real-time Redis statistics

## Configuration

Basic Redis configuration optimized for development:
- 256MB memory limit with LRU eviction
- Automatic persistence snapshots
- Password authentication enabled
- Logging level: notice

## Commands

```bash
# Deploy component
kubectl apply -k software/components/redis-infrastructure/

# Check component status
kubectl get all -n redis-infrastructure

# View Redis logs
kubectl logs -n redis-infrastructure deployment/redis

# View Commander logs
kubectl logs -n redis-infrastructure deployment/redis-commander

# Connect to Redis CLI
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword

# Remove component
kubectl delete -k software/components/redis-infrastructure/
```
