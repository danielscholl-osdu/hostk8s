# PostgreSQL Component (CloudNativePG Operator)

Provides CloudNativePG operator for PostgreSQL database management in HostK8s. This component enables stacks to create and manage PostgreSQL clusters with production-grade features like high availability, automated failover, and backup capabilities.

## Architecture

This component deploys the CloudNativePG operator to the `hostk8s` namespace, following the HostK8s operator placement strategy. Stacks can then create their own PostgreSQL clusters in dedicated namespaces.

## Resource Requirements

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| CNPG Operator | 50m | 200m | 64Mi | 256Mi |

## Quick Start

### Deploy Component

```bash
# Include in stack (recommended)
# In your stack.yaml:
- name: component-postgres
  namespace: flux-system
  path: ./software/components/postgres

# Or deploy standalone
kubectl apply -k software/components/postgres
```

### Verify Deployment

```bash
# Check operator status
kubectl get pods -n hostk8s -l hostk8s.component=postgres

# Verify CRDs are installed
kubectl get crd | grep cnpg
```

## Stack Usage Examples

Once the operator is deployed, stacks can create PostgreSQL clusters. Here are examples:

### Basic PostgreSQL Cluster

Create in your stack's app directory (e.g., `software/stacks/mystack/app/postgres/`):

```yaml
# namespace.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: mystack-db
  labels:
    app: mystack

---
# secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-superuser-secret
  namespace: mystack-db
type: kubernetes.io/basic-auth
stringData:
  username: postgres
  password: ChangeMeInProduction123!

---
# cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: mystack-postgres
  namespace: mystack-db
spec:
  instances: 1  # Single instance for development

  imageName: ghcr.io/cloudnative-pg/postgresql:16

  bootstrap:
    initdb:
      database: myapp
      owner: myapp
      secret:
        name: myapp-credentials

  storage:
    size: 1Gi
    storageClass: standard  # Or use hostPath with PVs

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

### High Availability Configuration

For production-like HA testing:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: ha-postgres
  namespace: production-db
spec:
  instances: 3  # 3 instances for HA

  primaryUpdateStrategy: unsupervised

  minSyncReplicas: 1
  maxSyncReplicas: 1

  replicationSlots:
    highAvailability:
      enabled: true

  storage:
    size: 10Gi
    storageClass: fast-ssd

  monitoring:
    enabled: true  # Enable if you have Prometheus
```

### Using HostPath Storage (Local Development)

For persistent storage in local development:

```yaml
# pv.yaml - Create PersistentVolumes
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mystack-postgres-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: postgres-local
  hostPath:
    path: /mnt/postgres/mystack  # Maps to ./data/postgres/mystack
    type: DirectoryOrCreate

---
# storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: postgres-local
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer

---
# cluster.yaml - Reference the storage class
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: mystack-postgres
  namespace: mystack-db
spec:
  storage:
    size: 5Gi
    storageClass: postgres-local
  # ... rest of configuration
```

### Stack Integration Pattern

In your stack's kustomization:

```yaml
# software/stacks/mystack/stack.yaml
---
# First ensure operator is deployed
- name: component-postgres
  namespace: flux-system
  path: ./software/components/postgres

---
# Then deploy your database
- name: mystack-database
  namespace: flux-system
  path: ./software/stacks/mystack/app/postgres
  dependsOn:
    - name: component-postgres
```

## Connection Patterns

### Application ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: myapp
data:
  DATABASE_HOST: mystack-postgres-rw.mystack-db.svc.cluster.local
  DATABASE_PORT: "5432"
  DATABASE_NAME: myapp
```

### Service Discovery

CNPG creates multiple services:
- `<cluster-name>-rw` - Read/write service (primary)
- `<cluster-name>-ro` - Read-only service (replicas)
- `<cluster-name>-r` - Any instance (read)

### Port Forwarding for Development

```bash
# Connect to primary for read/write
kubectl port-forward -n mystack-db svc/mystack-postgres-rw 5432:5432

# Connect with psql
psql -h localhost -U postgres -d myapp
```

## Advanced Features

### Backup Configuration

```yaml
spec:
  backup:
    retentionPolicy: "30d"
    barmanObjectStore:
      destinationPath: "s3://backup-bucket/postgres"
      s3Credentials:
        accessKeyId:
          name: s3-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: s3-credentials
          key: SECRET_ACCESS_KEY
```

### Custom PostgreSQL Configuration

```yaml
spec:
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      log_statement: "all"  # For development debugging
```

### TLS Configuration

```yaml
spec:
  certificates:
    serverTLSSecret: postgres-server-cert
    serverCASecret: postgres-ca-cert
    clientCASecret: postgres-ca-cert
    replicationTLSSecret: postgres-replication-cert
```

## Troubleshooting

### Check Operator Logs

```bash
kubectl logs -n hostk8s deployment/cnpg-controller-manager
```

### Cluster Not Starting

```bash
# Check cluster status
kubectl describe cluster -n <namespace> <cluster-name>

# Check pod events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Verify PVC is bound
kubectl get pvc -n <namespace>

# Check PV status
kubectl get pv
```

## CloudNativePG Resources

- [Official Documentation](https://cloudnative-pg.io/documentation/)
- [API Reference](https://cloudnative-pg.io/documentation/current/api_reference/)
- [Operator GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
- [Examples](https://github.com/cloudnative-pg/cloudnative-pg/tree/main/docs/src/samples)

## Component Contract

This component follows HostK8s standards:
- ✅ Operator deployed to `hostk8s` namespace
- ✅ Resource labels (`hostk8s.component: postgres`)
- ✅ Resource limits defined
- ✅ Health checks included
- ✅ Documentation complete
- ✅ Stack integration examples provided
