# Postgres Foundation Stack

Foundation stack providing PostgreSQL database with pgAdmin management UI for HostK8s development environments.

## Quick Start

Deploy the Postgres foundation stack:

```bash
make up foundation/postgres
```

## Components

- **CloudNativePG Operator**: Manages PostgreSQL clusters with backup/recovery
- **pgAdmin4**: Web-based PostgreSQL administration tool

## Access

| Service | Endpoint | Purpose |
|---------|----------|---------|
| PostgreSQL Operator | Kubernetes cluster | Manages PostgreSQL clusters |
| pgAdmin4 | http://pgadmin.localhost:8080/ | Web database administration |

## Creating a PostgreSQL Cluster

After deploying the foundation stack, create clusters in your applications:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-postgres
  namespace: my-app
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:16

  bootstrap:
    initdb:
      database: myapp
      owner: myapp
      secret:
        name: postgres-credentials

  storage:
    size: 1Gi
    storageClass: standard
```

## Database Connection

Connect to your PostgreSQL clusters using the services created by CloudNativePG:

```yaml
env:
- name: DATABASE_HOST
  value: "my-postgres-rw.my-app.svc.cluster.local"
- name: DATABASE_PORT
  value: "5432"
- name: DATABASE_NAME
  value: "myapp"
- name: DATABASE_USER
  valueFrom:
    secretKeyRef:
      name: postgres-credentials
      key: username
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-credentials
      key: password
```

## Secret Management

pgAdmin credentials are automatically generated through HostK8s secret contracts and stored in Vault.

## Resources

- **CloudNativePG Operator**: 50m CPU, 64Mi memory (requests), 200m CPU, 256Mi memory (limits)
- **pgAdmin4**: 100m CPU, 256Mi memory (requests), 250m CPU, 512Mi memory (limits)
