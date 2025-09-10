# Storage Contracts

Storage Contracts solve the complexity of managing persistent storage in Kubernetes by letting you declare what storage your stack needs in a simple YAML file. HostK8s handles creating all the Kubernetes resources automatically.

## Architecture Components

HostK8s storage architecture consists of four key components:

1. **Docker Volume** (`hostk8s-pv-data`): Physical storage backend that persists across cluster operations
2. **Storage Contract** (`hostk8s.storage.yaml`): Declares what storage directories you need
3. **Storage Class**: Tells Kubernetes how to handle storage provisioning for your stack
4. **Kubernetes Resources**: PersistentVolumes (PV) and PersistentVolumeClaims (PVC) for applications

## How It Works

```
You write              HostK8s creates       Your app uses
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Storage Contract│───▶│ Storage Class +  │───▶│ PVC gets        │
│ (what you need) │    │ PV automatically │    │ storage         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Volume                                │
│                   (physical storage)                            │
└─────────────────────────────────────────────────────────────────┘
```

HostK8s storage architecture consists of four key components:

1. **Docker Volume** (`hostk8s-pv-data`): Physical storage backend that persists across cluster operations
2. **Storage Contract** (`hostk8s.storage.yaml`): Declares what storage directories you need
3. **Storage Class**: Tells Kubernetes how to handle storage provisioning for your stack
4. **Kubernetes Resources**: PersistentVolumes (PV) and PersistentVolumeClaims (PVC) for applications

### 1. Storage Contract (`hostk8s.storage.yaml`)

**Purpose**: Declares what storage directories your stack needs

**What it does**:
- Creates directories in the Docker volume with proper permissions
- Generates PersistentVolumes that map to these directories
- Generates StorageClasses for the storage class names you specify

**Example**:
```yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: my-stack
  namespace: my-stack
spec:
  directories:
    - name: database-data
      path: /mnt/pv/database-data
      size: 10Gi
      accessModes: [ReadWriteOnce]
      storageClass: my-stack-database
      owner: "999:999"
      permissions: "755"
      component: database
      description: "Primary database storage"
```

### 2. StorageClass (Auto-Generated)

**Purpose**: Tells Kubernetes how to provision storage for your stack

**What it does**:
- Automatically created from storage class names in your contract
- Uses static provisioning (`kubernetes.io/no-provisioner`)
- Sets standard policies (Retain, WaitForFirstConsumer)

**Example** (created automatically):
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: my-stack-database  # From storageClass in contract
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
```

### 3. PersistentVolume (PV)

**Purpose**: Represents the actual storage available in the cluster

**What it does**:
- Maps to a specific directory in the Docker volume
- Defines size, access modes, and storage class
- Automatically created by the storage contract

**Example** (created automatically):
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostk8s-my-stack-database-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: my-stack-database
  hostPath:
    path: /mnt/pv/database-data
    type: DirectoryOrCreate
```

### 4. PersistentVolumeClaim (PVC)

**Purpose**: Applications use PVCs to request storage

**What it does**:
- References a storage class to find available PVs
- Automatically binds to a matching PV
- Mounts the storage into application pods

**Example** (you create this):
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
  namespace: my-stack
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: my-stack-database
  resources:
    requests:
      storage: 10Gi
```


## What Gets Created

When you run `make up my-stack`, the system automatically creates:

**1. Directory in Docker volume:**
```
hostk8s-pv-data/
└── postgres-data/          # Owner: 999:999, Permissions: 777
```

**2. PersistentVolume:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostk8s-my-stack-database-data  # hostk8s-{stack}-{directory-name}
spec:
  capacity:
    storage: 10Gi
  accessModes: [ReadWriteOnce]
  storageClassName: my-stack-database
  hostPath:
    path: /mnt/pv/database-data
```

**3. StorageClass:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: my-stack-database  # From storageClass in contract
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
```

Your application's PVC will automatically bind to the PV and mount the storage.

## Directory Specification

Each directory in a storage contract has these properties:

| Property | Required | Description | Purpose |
|----------|----------|-------------|---------|
| `name` | Yes | Unique identifier | Used in PV names and directory creation |
| `path` | Yes | Mount path inside containers | Where applications see the storage |
| `size` | Yes | Storage capacity | Sets PV size limit |
| `accessModes` | Yes | Kubernetes access modes | Defines how PVs can be mounted |
| `storageClass` | Yes | Storage class name | Links PVCs to PVs |
| `owner` | Yes | UID:GID ownership | Sets directory ownership in volume |
| `permissions` | Yes | Directory permissions | Controls access (755, 777, etc.) |
| `component` | Yes | Component identifier | Used in storage class naming |
| `description` | Yes | Human-readable description | Documentation |

## Usage

1. Create `software/stacks/your-stack/hostk8s.storage.yaml` (define what storage you need)
2. Run `make up your-stack` (HostK8s creates StorageClasses and PVs automatically)
3. Create PVCs in your applications that reference the storage class names from your contract
