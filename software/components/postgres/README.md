# PostgreSQL Component (CloudNativePG Operator)

PostgreSQL operator component that enables stacks to create and manage PostgreSQL clusters for local development with HostK8s.

## Quick Start

Add to your stack's `stack.yaml`:

```yaml
- name: component-postgres
  namespace: flux-system
  path: ./software/components/postgres
```

Then create PostgreSQL clusters in your stack applications.

## Creating a PostgreSQL Cluster

In your stack's application manifests, create a cluster:

```yaml
# cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: myapp-postgres
  namespace: myapp-db
spec:
  instances: 1

  imageName: ghcr.io/cloudnative-pg/postgresql:16

  bootstrap:
    initdb:
      database: myapp
      owner: myapp
      secret:
        name: myapp-credentials

  storage:
    size: 1Gi
    storageClass: standard

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 500m

  superuserSecret:
    name: postgres-superuser-secret
```

## Secret Management

Use HostK8s secret contracts in your stack's `hostk8s.secrets.yaml`:

```yaml
- name: postgres-superuser-secret
  namespace: myapp-db
  data:
    - key: username
      value: postgres
    - key: password
      generate: password
      length: 16

- name: myapp-credentials
  namespace: myapp-db
  data:
    - key: username
      value: myapp
    - key: password
      generate: password
      length: 16
```

## Connection

CloudNativePG creates multiple services for each cluster:

| Service | Endpoint | Purpose |
|---------|----------|---------|
| `<cluster>-rw` | `myapp-postgres-rw.myapp-db.svc.cluster.local:5432` | Read/write (primary) |
| `<cluster>-ro` | `myapp-postgres-ro.myapp-db.svc.cluster.local:5432` | Read-only (replicas) |
| `<cluster>-r` | `myapp-postgres-r.myapp-db.svc.cluster.local:5432` | Any instance |

## Application Configuration

```yaml
env:
- name: DATABASE_HOST
  value: "myapp-postgres-rw.myapp-db.svc.cluster.local"
- name: DATABASE_PORT
  value: "5432"
- name: DATABASE_NAME
  value: "myapp"
- name: DATABASE_USER
  valueFrom:
    secretKeyRef:
      name: myapp-credentials
      key: username
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: myapp-credentials
      key: password
```

## High Availability (Optional)

For development testing with multiple instances:

```yaml
spec:
  instances: 3
  minSyncReplicas: 1
  maxSyncReplicas: 1
  primaryUpdateStrategy: unsupervised
```

## Development Access

```bash
# Port forward to connect directly
kubectl port-forward -n myapp-db svc/myapp-postgres-rw 5432:5432

# Connect with psql
psql -h localhost -U myapp -d myapp
```

## Resources

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| CNPG Operator | 50m | 200m | 64Mi | 256Mi |

## Features

- **CloudNativePG Operator 0.26.0** with automatic updates
- **PostgreSQL 16** with development-optimized configuration
- **High availability** support with automatic failover
- **Backup and recovery** capabilities built-in
- **TLS encryption** support for secure local development
- **GitOps managed** with Flux v2
