# Redis Component (Bitnami Helm Chart)

Redis data store component providing in-memory caching and data storage with web management interface for HostK8s stacks.

## Quick Start

Add to your stack's `stack.yaml`:

```yaml
- name: component-redis
  namespace: flux-system
  path: ./software/components/redis
```

Then connect from your applications using the Redis service:

```yaml
env:
- name: REDIS_HOST
  value: "redis-master.redis-infrastructure.svc.cluster.local"
- name: REDIS_PORT
  value: "6379"
```

## Secret Management

For Redis Commander web UI, use HostK8s secret contracts in your stack's `hostk8s.secrets.yaml`:

```yaml
- name: redis-commander-credentials
  namespace: redis-infrastructure
  data:
    - key: username
      value: admin
    - key: password
      generate: password
      length: 12
```

## Services

| Service | Endpoint | Port | Purpose |
|---------|----------|------|---------|
| Redis Server | `redis-master.redis-infrastructure.svc.cluster.local` | 6379 | Application data store |
| Redis Commander | NodePort | 30833 | Web management interface |

## Connection Examples

**Basic Redis connection:**
```yaml
env:
- name: REDIS_URL
  value: "redis://redis-master.redis-infrastructure.svc.cluster.local:6379"
```

**With connection pooling:**
```yaml
env:
- name: REDIS_HOST
  value: "redis-master.redis-infrastructure.svc.cluster.local"
- name: REDIS_PORT
  value: "6379"
- name: REDIS_DB
  value: "0"
```

## Resources

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Redis Master | 100m | 250m | 256Mi | 512Mi |
| Redis Commander | 50m | 100m | 64Mi | 128Mi |

## Features

- **Bitnami Redis 18.19.4** with automatic semver updates
- **Persistent storage** with 8Gi default volume
- **Web management** via Redis Commander UI
- **Production ready** configuration with optimized settings
- **GitOps managed** with Flux v2 and OCIRepository source
