# Shared Components

Components provide shared capabilities that multiple applications can use. Think databases, certificate management, monitoring, and container registries. Components are the foundation blocks that make your applications possible. Need to work on just one component? Deploy it in isolation. Want to reuse a component in a different environment? Drop it right into a new stack.

## Component Index

| Component | Purpose | Resources | Documentation |
|-----------|---------|-----------|---------------|
| airflow | Workflow orchestration with CeleryExecutor and web UI | 450m CPU, 960Mi-1920Mi memory | [README](airflow/README.md) |
| certs | TLS certificate management with cert-manager | 30m CPU, 96Mi memory | [README](certs/README.md) |
| elasticsearch | Full-text search and analytics with Kibana dashboard | 300m CPU, 2.19-2.53Gi memory, 10Gi storage | [README](elasticsearch/README.md) |
| istio | Service mesh with ambient mode and Gateway API | ~300m CPU, ~384Mi memory | [README](istio/README.md) |
| postgres | PostgreSQL operator for database cluster management | 50m CPU, 64Mi-256Mi memory | [README](postgres/README.md) |
| redis | Redis data store with web management interface | 75m CPU, 192Mi memory, 1GB storage | [README](redis/README.md) |
| registry | Container registry for local image development | 100m CPU, 128Mi memory, 10GB storage | [README](registry/README.md) |

## Component Contract

Components must conform to these requirements to integrate with HostK8s stacks:

### Required Files
```
software/components/{component-name}/
├── kustomization.yaml          # Resource orchestration (required)
└── README.md                  # Component documentation (required)
```

**Implementation Patterns:**
- **Helm-based**: `source.yaml` + `release.yaml` (simple deployments)
- **Orchestrated**: `component.yaml` + subdirectories (complex components requiring dependency management)
- **Direct**: Raw Kubernetes resources like `deployment.yaml`, `service.yaml`, `namespace.yaml` (simple components)

### Required Standards
- **Namespace isolation**: Each component deploys to dedicated namespace
- **Resource labels**: Apply `hostk8s.component: {name}` to all resources
- **Resource limits**: Define CPU and memory requests and limits
- **Health checks**: Include readiness and liveness probes
- **Documentation**: Follow established README pattern with resource requirements, architecture, integration examples
- **Contract support**: Use SecretContract and StorageContract when managing secrets or persistent data

### Contract Integration (Optional)

Components can support declarative secret and storage management:

**SecretContract** (`hostk8s.secrets.yaml`):
```yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: {stack-name}
spec:
  secrets:
    - name: {secret-name}
      namespace: {namespace}
      data:
        - key: password
          generate: password
```

**StorageContract** (`hostk8s.storage.yaml`):
```yaml
apiVersion: hostk8s.io/v1
kind: StorageContract
metadata:
  name: {stack-name}
spec:
  directories:
    - name: {directory-name}
      path: /mnt/pv/{path}
      size: 5Gi
      accessModes: ["ReadWriteOnce"]
      storageClass: {storage-class-name}
```

### Stack Integration
Stacks reference components in their `stack.yaml`:

```yaml
- name: component-{name}
  namespace: flux-system
  path: ./software/components/{name}
```
