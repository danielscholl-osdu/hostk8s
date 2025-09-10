# Storage Contracts

Storage Contracts provide a declarative way to define and manage persistent storage requirements for HostK8s stacks. Similar to Secret Contracts, they ensure proper isolation, lifecycle management, and consistent storage setup across different environments.

## Overview

Storage Contracts solve the challenge of managing persistent storage for multiple components within a stack while maintaining:

- **Component Isolation**: Each component gets its own storage namespace
- **Lifecycle Management**: Storage created with `make up`, cleaned with `make down`
- **Cross-Platform Consistency**: Works reliably on Windows, Mac, and Linux
- **Declarative Configuration**: Storage requirements defined in code

## Architecture

```
hostk8s/
├── software/stacks/sample-app/
│   ├── hostk8s.storage.yaml        # Storage contract (defines requirements)
│   └── manifests/
│       ├── database.yaml           # Uses storage defined in contract
│       └── other-components.yaml
└── data/
    └── # Physical storage managed by Docker volume (cross-platform)
```

## Storage Contract Format

Create a `hostk8s.storage.yaml` file in your stack directory:

```yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: sample-app
  namespace: sample-app
spec:
  directories:
    # PostgreSQL database storage
    - name: postgres-voting
      path: /mnt/pv/postgres-voting
      size: 5Gi
      accessModes:
        - ReadWriteOnce
      storageClass: hostk8s-storage
      owner: "999:999"          # PostgreSQL UID:GID
      permissions: "777"         # Allow PostgreSQL to create subdirectories
      component: postgres
      description: "Voting application PostgreSQL database"

    # Application file uploads
    - name: app-uploads
      path: /mnt/pv/uploads
      size: 1Gi
      accessModes:
        - ReadWriteOnce
      storageClass: hostk8s-storage
      owner: "1000:1000"        # Application UID:GID
      permissions: "755"
      component: application
      description: "User file uploads storage"

    # Shared cache storage
    - name: redis-cache
      path: /mnt/pv/redis-cache
      size: 2Gi
      accessModes:
        - ReadWriteOnce
      storageClass: hostk8s-storage
      owner: "999:999"          # Redis UID:GID
      permissions: "755"
      component: redis
      description: "Redis cache persistent storage"
```

## Directory Specification

Each directory in the contract has these properties:

| Property | Required | Description | Example |
|----------|----------|-------------|---------|
| `name` | Yes | Unique identifier for this storage | `postgres-voting` |
| `path` | Yes | Mount path inside containers | `/mnt/pv/postgres-voting` |
| `size` | Yes | Storage capacity | `5Gi`, `1Gi` |
| `accessModes` | Yes | Kubernetes access modes | `ReadWriteOnce` |
| `storageClass` | Yes | Storage class to use | `hostk8s-storage` |
| `owner` | Yes | UID:GID ownership | `999:999` (postgres) |
| `permissions` | Yes | Directory permissions | `777`, `755`, `700` |
| `component` | Yes | Component that uses this storage | `postgres`, `redis` |
| `description` | Yes | Human-readable description | Storage purpose |

## Common Ownership Patterns

| Component | UID:GID | Permissions | Use Case |
|-----------|---------|-------------|----------|
| PostgreSQL | `999:999` | `777` | Database needs to create pgdata subdirectory |
| Redis | `999:999` | `755` | Cache storage, standard permissions |
| Application | `1000:1000` | `755` | Web app file storage |
| NGINX | `101:101` | `755` | Static file serving |

## Usage

### 1. Create Storage Contract

Create `software/stacks/your-stack/hostk8s.storage.yaml` with your storage requirements.

### 2. Deploy Stack

```bash
make up your-stack
```

This will:
- Process the storage contract
- Create PersistentVolumes and PersistentVolumeClaims
- Set up directory permissions in the cluster
- Deploy your stack components

### 3. Use Storage in Components

Reference the storage in your Kubernetes manifests:

```yaml
# database.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: voting-db
spec:
  storage:
    storageClass: hostk8s-storage    # Matches contract
    size: 5Gi                        # Matches contract
    # PVC will automatically bind to postgres-voting PV
```

### 4. Clean Up

```bash
make down your-stack
```

This removes:
- PersistentVolumeClaims
- Storage directory contents
- Stack resources

Note: PersistentVolumes are retained for data safety.

## Multiple Databases Example

For stacks needing multiple databases:

```yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: multi-tier-app
spec:
  directories:
    # Primary application database
    - name: postgres-primary
      path: /mnt/pv/postgres-primary
      size: 10Gi
      accessModes: [ReadWriteOnce]
      storageClass: hostk8s-storage
      owner: "999:999"
      permissions: "777"
      component: postgres
      description: "Primary application database"

    # Analytics database
    - name: postgres-analytics
      path: /mnt/pv/postgres-analytics
      size: 20Gi
      accessModes: [ReadWriteOnce]
      storageClass: hostk8s-storage
      owner: "999:999"
      permissions: "777"
      component: postgres
      description: "Analytics and reporting database"

    # Shared application storage
    - name: app-shared
      path: /mnt/pv/shared
      size: 5Gi
      accessModes: [ReadWriteOnce]
      storageClass: hostk8s-storage
      owner: "1000:1000"
      permissions: "755"
      component: application
      description: "Shared application files"
```

## Cross-Platform Notes

### Windows Compatibility
- Uses Docker volumes for reliable NTFS permission handling
- Automatic UID/GID mapping through Docker Desktop
- No manual permission management required

### Mac/Linux Compatibility
- Direct host path mounting through Kind cluster
- Consistent behavior across Unix-like systems
- Same permission model as Windows

## Lifecycle Management

Storage Contracts follow the same lifecycle as Secret Contracts:

1. **Creation**: `make up stack-name` processes storage contract
2. **Updates**: Modify contract and run `make up stack-name` again
3. **Removal**: `make down stack-name` cleans up storage
4. **Persistence**: Data survives cluster restarts (`make restart`)

## Best Practices

### Directory Naming
- Use descriptive names: `postgres-voting`, `redis-cache`
- Include component type: `postgres-*`, `redis-*`, `app-*`
- Avoid generic names: `data`, `storage`, `files`

### Permissions
- Start with least privilege (755)
- Use 777 only when component needs to create subdirectories
- Document why specific permissions are needed

### Size Planning
- Start conservatively, storage can be expanded
- Consider data growth over time
- Account for backups and temporary files

### Component Isolation
- One directory per database instance
- Separate storage for different data types
- Clear ownership boundaries

## Integration with GitOps

Storage Contracts integrate seamlessly with Flux GitOps:

1. **Declare**: Storage contract in Git repository
2. **Process**: `make up` processes contract and creates resources
3. **Deploy**: Flux deploys components that use the storage
4. **Persist**: Data survives GitOps updates and deployments

The storage infrastructure is prepared before Flux deploys components, ensuring smooth deployments.

## Troubleshooting

### Permission Denied Errors
Check that:
- Directory ownership matches component requirements
- Permissions allow component to write
- Path exists and is mounted correctly

### Storage Not Found
Verify:
- Storage contract is valid YAML
- `make up stack-name` was run successfully
- PersistentVolume exists and is Available

### Cross-Platform Issues
Ensure:
- Using `hostk8s-storage` storage class
- Docker volume is created and mounted
- Kind cluster has access to volume

## Technical Implementation

Storage Contracts are processed by:
1. `manage-storage.py` - Parses contracts and creates Kubernetes resources
2. `cluster-up.py` - Sets up Docker volume and directory permissions
3. `deploy-stack.py` - Integrates storage setup with stack deployment

This provides a clean separation between storage management and application deployment.
