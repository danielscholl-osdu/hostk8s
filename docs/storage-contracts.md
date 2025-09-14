# Storage Contract Specification

## Overview

Storage contracts provide a declarative interface for managing persistent storage in Kubernetes development environments. Applications declare their storage requirements through `StorageContract` resources, and HostK8s automatically provisions directories, StorageClasses, and PersistentVolumes using host-mode data persistence.

Storage Contracts implement the [host-mode data persistence architecture](adr/012-host-mode-data-persistence-architecture.md) established in HostK8s.

## Terminology

To clarify the relationship between contract fields and Kubernetes resources:

| StorageContract Term | Kubernetes Equivalent | Description |
|---------------------|----------------------|-------------|
| `spec.directories[].name` | `PersistentVolume.metadata.name` | Used to generate the PersistentVolume name |
| `spec.directories[].storageClass` | `StorageClass.metadata.name` | The name of the StorageClass that will be created |
| `spec.directories[].path` | `PersistentVolume.spec.hostPath.path` | Host path mapped to container mount point |
| `spec.directories[].size` | `PersistentVolume.spec.capacity.storage` | Storage capacity allocated to the volume |

**Resource relationships:**
- Each **directory** in a contract → **1 PersistentVolume** + host directory
- Each **unique storageClass** → **1 StorageClass resource** (shared across directories with same name)
- Applications create **PVCs** that bind to the declared `storageClass` names

**Example mapping:**
```yaml
# StorageContract declares this:
directories:
  - name: app-data                    # → Creates PV named "hostk8s-{stack}-app-data-pv"
    storageClass: my-stack-storage    # → Creates StorageClass named "my-stack-storage"
    path: /mnt/pv/app-data           # → PV hostPath points to this container path
    size: 5Gi                        # → PV capacity set to 5Gi
```

## Schema Definition

### Contract Structure

```yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: {stack-name}
  namespace: {namespace}
spec:
  directories:
    - name: {directory-name}
      path: {mount-path}
      size: {capacity}
      accessModes: [{access-mode}]
      storageClass: {storage-class-name}
      owner: {uid:gid}
      permissions: {mode}
```

### Field Specification

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `apiVersion` | string | Required | Must be `hostk8s.io/v1` |
| `kind` | string | Required | Must be `StorageContract` |
| `metadata.name` | string | Required | Stack name (must match the deploying stack) |
| `metadata.namespace` | string | Required | Namespace for the StorageContract resource |
| `spec.directories` | array | Required | List of storage directories to create (minimum 1) |
| `spec.directories[].name` | string | Required | Unique directory identifier (used in PV names) |
| `spec.directories[].path` | string | Required | Mount path inside containers |
| `spec.directories[].size` | string | Required | Storage capacity (e.g., "5Gi", "100Mi") |
| `spec.directories[].accessModes` | array | Required | Kubernetes access modes (e.g., `["ReadWriteOnce"]`) |
| `spec.directories[].storageClass` | string | Required | StorageClass name for PVC binding |
| `spec.directories[].owner` | string | Optional | Directory ownership in `uid:gid` format (default: `1000:1000`) |
| `spec.directories[].permissions` | string | Optional | Directory permissions in octal format (default: `755`) |

## Validation Rules

### Contract Requirements
- Contract `metadata.name` must match the deploying stack name (used for directory organization)
- At least one directory must be defined in `spec.directories`
- Each directory `name` must be unique within the contract
- StorageClass names can be shared across directories to enable multiple PVs with the same storage class

### Directory Constraints
- Directory names must follow Kubernetes naming conventions (DNS-1123 subdomain)
- Directory paths must follow the `/mnt/pv/` convention (per ADR-012)
- Storage capacity must use valid Kubernetes resource quantities (e.g., `1Gi`, `500Mi`)
- Access modes must be valid Kubernetes PersistentVolume access modes
- Owner format must be `uid:gid` (e.g., `1000:1000`)
- Permissions must be valid octal notation (e.g., `755`, `644`)

## Directory Properties

Each directory in a storage contract supports the following configuration:

| Property | Purpose | Example Values |
|----------|---------|----------------|
| `name` | Unique identifier for PV generation | `app-data`, `database-storage` |
| `path` | Container mount point | `/mnt/pv/app-data`, `/mnt/database` |
| `size` | Storage capacity allocation | `1Gi`, `500Mi`, `10Gi` |
| `accessModes` | Volume access patterns | `["ReadWriteOnce"]`, `["ReadWriteMany"]` |
| `storageClass` | PVC binding reference | `my-app-storage`, `database-storage` |
| `owner` | Directory ownership | `1000:1000`, `999:999` |
| `permissions` | Directory access permissions | `755`, `644`, `700` |

## Lifecycle

When you run `make up {stack-name}`, HostK8s automatically processes any `hostk8s.storage.yaml` file:

1. **Contract parsing** → schema validation
2. **Directory provisioning** → ensure host directories exist with ownership and permissions
3. **StorageClass creation** → generate StorageClasses from declared names
4. **Volume creation** → generate PVs mapped to host paths
5. **Application binding** → applications request volumes by creating PVCs that reference the declared StorageClasses

## Using Storage in Applications

Once your storage contract is processed, applications can request storage by creating PersistentVolumeClaims that reference the StorageClass names:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
  namespace: my-app
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: my-app-storage    # From contract: directories[].storageClass
  resources:
    requests:
      storage: 5Gi
```

The StorageClass name in your PVC must match exactly what you declared in your StorageContract.

## Example

```yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: my-app
  namespace: my-app
spec:
  directories:
    - name: database-storage          # Database persistent storage
      path: /mnt/pv/database
      size: 10Gi
      accessModes: ["ReadWriteOnce"]
      storageClass: my-app-database
      owner: "999:999"                # PostgreSQL user
      permissions: "700"

    - name: app-data                  # Application data storage
      path: /mnt/pv/app-data
      size: 5Gi
      accessModes: ["ReadWriteOnce"]
      storageClass: my-app-storage
      # Uses defaults: owner 1000:1000, permissions 755

    - name: shared-cache              # Shared cache storage
      path: /mnt/pv/cache
      size: 2Gi
      accessModes: ["ReadWriteMany"]
      storageClass: my-app-shared
```
