# Redis Foundation Stack

Foundation stack providing Redis data store with Redis Commander management UI for HostK8s development environments.

## Quick Start

Deploy the Redis foundation stack:

```bash
make up foundation/redis
```

## Components

- **Redis Server**: In-memory data store on port 6379
- **Redis Commander**: Web-based management UI

## Access

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Redis Server | `redis.redis.svc.cluster.local:6379` | Application connections |
| Redis Commander | NodePort 30081 | Web management interface |

## Application Integration

Connect your applications using:

```yaml
env:
- name: REDIS_HOST
  value: "redis.redis.svc.cluster.local"
- name: REDIS_PORT
  value: "6379"
```

Or with URL format:
```yaml
env:
- name: REDIS_URL
  value: "redis://redis.redis.svc.cluster.local:6379"
```

## Secret Management

Redis Commander credentials are automatically generated through HostK8s secret contracts and stored in Vault.

## Resources

- **Redis**: 100m CPU, 128Mi memory (requests), 200m CPU, 256Mi memory (limits)
- **Redis Commander**: 50m CPU, 64Mi memory (requests), 100m CPU, 128Mi memory (limits)
