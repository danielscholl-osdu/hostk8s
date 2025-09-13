# Storage Contracts

Storage Contracts solve the complexity of managing persistent storage in Kubernetes by letting you declare what storage your stack needs in a simple YAML file. HostK8s handles creating all the Kubernetes resources automatically.

Storage Contracts provide the modern declarative interface to the [host-mode data persistence architecture](adr/012-host-mode-data-persistence-architecture.md) established in HostK8s.

## Architecture Components

HostK8s storage architecture consists of four key components:

1. **Docker Volume** (`hostk8s-pv-data`): Physical storage backend that persists across cluster operations
2. **Storage Contract** (`hostk8s.storage.yaml`): Declares what storage directories you need
3. **Storage Class**: Tells Kubernetes how to handle storage provisioning for your stack
4. **Kubernetes Resources**: PersistentVolumes (PV) and PersistentVolumeClaims (PVC) for applications

## How It Works

```
     You write            HostK8s creates         You create
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Storage Contract│───▶│ Storage Class +  │───▶│ PVC (reference  │
│ (what you need) │    │ PV automatically │    │ storage class)  │
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
    - name: app-data
      path: /mnt/pv/app-data
      size: 5Gi
      accessModes: [ReadWriteOnce]
      storageClass: my-stack-storage
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
  name: my-stack-storage  # From storageClass in contract
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
```

### 3. PersistentVolume (Auto-Generated)

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
  name: hostk8s-my-stack-app-data-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: my-stack-storage
  hostPath:
    path: /mnt/pv/app-data
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
  name: app-storage
  namespace: my-stack
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: my-stack-storage
  resources:
    requests:
      storage: 5Gi
```


## What Gets Created

When you run `make up my-stack`, the system automatically creates:

**1. Directory in Docker volume:**
```
hostk8s-pv-data/
└── app-data/               # Owner: 1000:1000, Permissions: 755
```

**2. PersistentVolume:**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostk8s-my-stack-app-data-pv  # hostk8s-{stack}-{directory-name}-pv
spec:
  capacity:
    storage: 5Gi
  accessModes: [ReadWriteOnce]
  storageClassName: my-stack-storage
  hostPath:
    path: /mnt/pv/app-data
```

**3. StorageClass:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: my-stack-storage  # From storageClass in contract
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
```

## Directory Properties

| Property | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Unique identifier used in PV names |
| `path` | Yes | Mount path inside containers |
| `size` | Yes | Storage capacity (e.g., "5Gi") |
| `accessModes` | Yes | Kubernetes access modes (e.g., `[ReadWriteOnce]`) |
| `storageClass` | Yes | Storage class name for PVC binding |
| `owner` | No | Directory ownership (default: `1000:1000`) |
| `permissions` | No | Directory permissions (default: `755`) |

## Using Storage in Applications

Reference storage using standard Kubernetes PersistentVolumeClaims:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
  namespace: my-stack
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: my-stack-storage  # From your contract
  resources:
    requests:
      storage: 5Gi
```

## Usage

Storage contracts are processed automatically when you deploy stacks:

```bash
make up {stack-name}  # Processes hostk8s.storage.yaml if it exists
```

HostK8s creates directories, StorageClasses, and PersistentVolumes automatically. Your applications reference the storage classes in their PVCs to bind to the available storage.
