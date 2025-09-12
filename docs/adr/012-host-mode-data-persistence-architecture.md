# ADR-012: Host-Mode Data Persistence Architecture

## Status
**Accepted** - 2025-09-01

## Context
Host-mode Kubernetes development environments require sophisticated data persistence strategies that balance development velocity with production-like capabilities. Traditional approaches using ephemeral storage or complex persistent volume operators create barriers to rapid iteration and reliable data management for local development workflows.

**Data Persistence Requirements:**
- Service-specific data isolation for different infrastructure components
- Stack-aware persistent storage that survives cluster recreation
- Cross-cluster data survival for development iteration cycles
- Simple integration patterns for applications and components
- Host-mode architecture compatibility with Kind extraMounts
- Minimal operational overhead for developers

**Data Management Challenge:**
Development environments need to separate cluster lifecycle from data lifecycle. Applications require reliable persistent storage that survives pod restarts, cluster rebuilds, and development iterations, while maintaining service isolation and avoiding complex storage operators unsuitable for local development.

## Decision
Adopt **organized host-mode data persistence architecture** using dedicated directory structure with service-specific isolation and Kind extraMounts integration for seamless container access.

**Architecture Components:**
- **Service-Specific Directories**: Dedicated folders for each infrastructure service (`kubeconfig/`, `registry/`, `postgres/`)
- **Stack-Aware Organization**: Stack-specific persistent volumes under `data/pv/<stack-name>/`
- **Kind Integration**: extraMounts configuration mapping host directories to container mount points
- **Application Contracts**: Standardized mount point patterns for consistent application integration
- **Storage Contracts**: Declarative YAML interface for managing persistent storage requirements

## Rationale

### Data Organization Benefits
1. **Service Isolation** - Each infrastructure service has dedicated storage preventing conflicts and enabling independent lifecycle management
2. **Stack Organization** - Stack-specific directories under `data/pv/` enable multiple environments with isolated data
3. **Developer Mental Model** - Clear directory structure makes data location and ownership immediately apparent
4. **Backup/Migration Simplicity** - Organized structure enables selective backup and easy migration of specific services or stacks

### Host-Mode Integration Advantages
1. **Performance** - Direct host filesystem access eliminates storage abstraction layers
2. **Debugging** - Host directory access enables standard filesystem tools for inspection and recovery
3. **Persistence Guarantee** - Data survives cluster destruction, pod eviction, and development iteration cycles
4. **Cross-Platform Compatibility** - Works consistently across Mac, Linux, and Windows with Docker Desktop

### Application Integration Benefits
1. **Standardized Mount Points** - Consistent `/mnt/` prefixed paths for all persistent storage
2. **Contract-Based Design** - Applications use predictable mount points regardless of underlying host structure
3. **Stack Isolation** - `/mnt/pv/<stack-name>/` pattern enables multi-stack environments
4. **Service Discovery** - Service-specific mount points (`/mnt/postgres/`, `/mnt/registry/`) provide predictable integration

### Storage Contract Integration
1. **Declarative Interface** - YAML-based storage contracts eliminate manual resource creation
2. **Automatic Resource Generation** - StorageClasses and PersistentVolumes created automatically
3. **Infrastructure Abstraction** - Developers declare storage needs without Kubernetes complexity
4. **Consistency** - Follows established contract patterns for secrets and other platform resources

## Alternatives Considered

### 1. Ephemeral Storage Only
- **Pros**: Simple setup, no persistence complexity, fast cluster creation/destruction
- **Cons**: Data loss on cluster restart, no development continuity, limited to stateless applications
- **Decision**: Rejected due to development workflow requirements

### 2. Kubernetes Persistent Volume Operators (Longhorn, OpenEBS)
- **Pros**: Production-like storage, advanced features, Kubernetes-native management
- **Cons**: Operational overhead, resource consumption, complexity unsuitable for local development
- **Decision**: Rejected due to host-mode simplicity requirements

### 3. Single Shared Data Directory
- **Pros**: Simple structure, single mount point, minimal configuration
- **Cons**: No service isolation, conflict potential, unclear data ownership, backup complexity
- **Decision**: Rejected due to service isolation requirements

### 4. Docker Volume Management
- **Pros**: Docker-native, automatic lifecycle management, cross-container sharing
- **Cons**: Opaque storage location, debugging difficulty, platform-specific behavior
- **Decision**: Rejected due to transparency and debugging requirements

## Architecture Benefits

### Storage Architecture Evolution

**Current Architecture (Docker Volume)**:
```
hostk8s-pv-data/              # Universal Docker volume
├── app-data/                 # Storage contract directories
├── postgres-data/            # Database storage
└── <contract-directory>/     # Additional contract storage

data/                         # Host-accessible directories
├── kubeconfig/              # Cluster connection configuration
│   └── config              # kubectl configuration file
└── registry/               # Container registry storage
    └── docker/             # Registry data and metadata
```

**Legacy Structure (Deprecated)**:
```
data/
├── postgres/               # Direct PostgreSQL storage (deprecated)
├── pv/                    # Manual PV directories (deprecated)
│   ├── sample/           # Manual stack data (deprecated)
│   └── <stack>/          # Manual storage (deprecated)
└── storage/              # General storage (deprecated)
```

### Kind extraMounts Integration

**Current Implementation (Docker Volume)**:
```yaml
# infra/kubernetes/kind-custom.yaml
extraMounts:
  - hostPath: /var/lib/docker/volumes/hostk8s-pv-data/_data
    containerPath: /mnt/pv      # Universal storage mount point
```

**Legacy Implementation (Deprecated)**:
```yaml
# Manual directory mounting (superseded by Docker volume)
extraMounts:
  - hostPath: ./data/storage    # General storage (deprecated)
    containerPath: /mnt/storage
  - hostPath: ./data/pv         # Stack persistent volumes (deprecated)
    containerPath: /mnt/pv
  - hostPath: ./data/postgres   # Database storage (deprecated)
    containerPath: /mnt/postgres
```

### Application Integration Pattern

**Modern Approach (Storage Contracts)**:
```yaml
# software/stacks/sample/hostk8s.storage.yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: sample
  namespace: sample
spec:
  directories:
    - name: api-data
      path: /mnt/pv/api-data
      size: 1Gi
      accessModes: [ReadWriteOnce]
      storageClass: sample-storage
# Automatically generates PV, StorageClass, and directories
```

**Generated Resources (Automatic)**:
```yaml
# Auto-generated PersistentVolume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: hostk8s-sample-api-data-pv
spec:
  capacity:
    storage: 1Gi
  hostPath:
    path: /mnt/pv/api-data      # Maps to data/pv/api-data/
    type: DirectoryOrCreate
```

### Service Integration Model
```yaml
# Service-specific storage contracts
PostgreSQL:     /mnt/postgres/  → data/postgres/
Registry:       /mnt/storage/   → data/storage/ (legacy)
Stack PVs:      /mnt/pv/        → data/pv/
Applications:   /mnt/pv/<name>/ → data/pv/<stack-name>/

# Storage Contract Integration
Contract:       hostk8s.storage.yaml → StorageClass + PV + directories
Docker Volume:  hostk8s-pv-data      → /mnt/pv/ (universal backend)
```

## Consequences

**Positive:**
- Complete data persistence across all cluster lifecycle operations (restart, rebuild, recreation)
- Service isolation prevents data conflicts and enables independent service management
- Stack-aware organization supports multiple development environments simultaneously
- Standard mount point contracts provide predictable application integration patterns
- Host directory access enables standard filesystem tools for debugging and recovery
- Platform-agnostic storage using native Docker Desktop capabilities

**Negative:**
- Directory structure complexity requires understanding of service-to-directory mappings
- Host filesystem dependencies limit portability compared to cloud-native storage
- Manual data cleanup required when removing stacks or services permanently
- Storage capacity limited by host filesystem rather than dynamic allocation

## Implementation Notes

### Directory Creation Strategy
```bash
# Automatic directory creation in cluster-up.py
mkdir -p data/kubeconfig
mkdir -p data/storage
mkdir -p data/pv
mkdir -p data/postgres
mkdir -p data/registry
```

### Storage Contract Processing
```bash
# Modern approach: Storage contracts automatically manage resources
make up sample-app
├── manage-storage.py setup sample-app    # Process storage contract
├── manage-secrets.py add sample-app      # Process secret contract
└── deploy-stack.py sample-app            # Deploy stack via Flux

# Contract-based directory creation with permissions
# Based on hostk8s.storage.yaml declarations
```

### Stack-Specific Volume Creation (Legacy)
```bash
# Manual approach (superseded by storage contracts)
# Example: deploying 'sample' stack creates data/pv/sample/
mkdir -p "data/pv/${STACK_NAME}"
```

### Service Integration Patterns
```bash
# Registry service uses data/registry/
registry_data_dir="${PWD}/data/registry"

# Applications use /mnt/pv/<stack>/ mount points
# PersistentVolume hostPath: /mnt/pv/<stack-name>/
```

### Cross-Platform Considerations
```bash
# Unix/Linux/Mac: Standard directory permissions
chmod 755 data/pv data/storage data/postgres

# Windows: Docker Desktop volume mounting handles permissions
```

## Success Criteria
- Data persists across cluster restart, rebuild, and recreation operations
- Multiple stacks can maintain isolated persistent storage simultaneously
- Service-specific data remains isolated and independently manageable
- Applications integrate using standardized mount point contracts
- Host directory structure enables debugging and backup operations
- Performance matches or exceeds native filesystem access patterns

## Related ADRs
- [ADR-001: Host-Mode Architecture](001-host-mode-architecture.md) - Establishes host-mode foundation for data persistence
- [ADR-007: Kind Configuration Fallback System](007-kind-configuration-fallback-system.md) - Kind configuration includes extraMounts setup
- [ADR-011: Hybrid Container Registry Architecture](011-hybrid-container-registry-architecture.md) - Registry service uses data persistence patterns
- [ADR-013: Secret Contract Architecture](013-secret-contract-architecture.md) - Establishes contract-based pattern for platform resources
- [ADR-014: Vault Secret Management](014-vault-secret-management.md) - Related contract-based resource management approach

## References
- Kind extraMounts Documentation: https://kind.sigs.k8s.io/docs/user/configuration/#extra-mounts
- Docker Desktop Storage: https://docs.docker.com/desktop/settings/
- Kubernetes PersistentVolume Guide: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
