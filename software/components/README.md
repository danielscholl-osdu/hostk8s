# Shared Components

Components provide shared capabilities that multiple applications can use. Think databases, certificate management, monitoring, and container registries. Components are the foundation blocks that make your applications possible. Need to work on just one component? Deploy it in isolation. Want to reuse a component in a different environment? Drop it right into a new stack.

## Component Index

| Component | Purpose | Resources | Documentation |
|-----------|---------|-----------|---------------|
| certs | TLS certificate management with cert-manager | 30m CPU, 96Mi memory | [README](certs/README.md) |
| metrics-server | Kubernetes resource metrics for HPA and monitoring | 50m CPU, 64Mi memory | [README](metrics-server/README.md) |
| redis-infrastructure | Redis data store with web management interface | 75m CPU, 192Mi memory, 1GB storage | [README](redis-infrastructure/README.md) |
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
- **Helm-based**: `source.yaml` + `release.yaml` (metrics-server)
- **Nested**: `component.yaml` + subdirectories (certs)
- **Direct**: Kubernetes resources like `deployment.yaml`, `service.yaml`, `namespace.yaml` (redis-infrastructure, registry)

### Required Standards
- **Namespace isolation**: Each component deploys to dedicated namespace
- **Resource labels**: Apply `hostk8s.component: {name}` to all resources
- **Resource limits**: Define CPU and memory requests and limits
- **Health checks**: Include readiness and liveness probes
- **Documentation**: Follow established README pattern with resource requirements, architecture, integration examples

### Stack Integration
Stacks reference components in their `stack.yaml`:

```yaml
- name: component-{name}
  namespace: flux-system
  path: ./software/components/{name}
```
