# ADR-010: Infrastructure Addon Namespace Consolidation

## Status
**Accepted** - 2025-08-29

## Context
HostK8s infrastructure addons (MetalLB, NGINX Ingress, Container Registry, Metrics Server) were initially deployed using their respective default namespaces: `metallb-system`, `ingress-nginx`, `registry`, `kube-system`. This approach follows upstream conventions but creates operational complexity in development environments.

**Current Namespace Proliferation:**
Multiple isolated namespaces increase management overhead, complicate RBAC configuration, and create discoverability issues for developers working with local development clusters. Each addon requires separate namespace-aware kubectl commands, making cluster observation and debugging more complex.

**Development Environment Requirements:**
Unlike production environments where namespace isolation provides security and resource boundaries, local development clusters prioritize operational simplicity and developer productivity. The security isolation benefits of separate namespaces provide minimal value in single-developer, ephemeral development environments.

## Decision
Consolidate infrastructure addons into a **unified `hostk8s` namespace** while preserving component isolation through labels and resource naming conventions.

**Implementation Strategy:**
- Deploy MetalLB, NGINX Ingress, Container Registry UI, and related infrastructure components to `hostk8s` namespace
- Maintain `kube-system` namespace for core Kubernetes components (metrics-server)
- Preserve `flux-system` namespace for GitOps operations
- Use consistent resource labeling (`hostk8s.component: <name>`) for component identification

## Rationale

### Operational Simplification
1. **Single Discovery Point** - `kubectl get all -n hostk8s` shows all infrastructure components
2. **Simplified RBAC** - Single namespace reduces permission complexity for development workflows
3. **Consistent Resource Management** - Unified resource limits and monitoring across infrastructure
4. **Developer Experience** - Single namespace reduces cognitive load and command complexity

### Resource Organization
1. **Logical Grouping** - Infrastructure addons serve the same purpose: enabling application development
2. **Cross-Component Dependencies** - NGINX Ingress depends on MetalLB; registry UI depends on NGINX Ingress
3. **Shared Resource Pools** - Development clusters benefit from consolidated resource allocation
4. **Consistent Lifecycle** - All infrastructure addons share the same lifecycle (created during cluster setup)

### Label-Based Separation
```bash
kubectl get pods -n hostk8s -l hostk8s.component=metallb
kubectl get pods -n hostk8s -l hostk8s.component=ingress-nginx
kubectl get pods -n hostk8s -l hostk8s.component=registry
```

## Alternatives Considered

### 1. Maintain Upstream Namespace Conventions
- **Pros**: Follows upstream documentation, familiar to experienced users, stronger isolation
- **Cons**: Increased operational complexity, discovery challenges, RBAC proliferation
- **Decision**: Rejected due to development environment optimization priority

### 2. Single Global Namespace (default)
- **Pros**: Maximum simplicity, no namespace management required
- **Cons**: No component organization, potential resource naming conflicts, poor separation of concerns
- **Decision**: Rejected due to lack of organizational structure

### 3. Per-Stack Namespaces
- **Pros**: Stack-aware organization, clear resource boundaries per deployment
- **Cons**: Dynamic namespace creation complexity, cross-stack dependency challenges
- **Decision**: Rejected due to infrastructure vs application concern mixing

## Consequences

**Positive:**
- Reduced cognitive load for developers working with infrastructure components
- Simplified cluster observation and debugging workflows
- Consistent resource management across infrastructure components
- Easier RBAC configuration for development environments
- Single discovery point for all infrastructure status

**Negative:**
- Deviation from upstream namespace conventions may confuse experienced users
- Reduced namespace-level isolation between infrastructure components
- Potential for resource naming conflicts requiring careful naming conventions
- Documentation updates required for components referencing old namespaces

## Implementation Notes

### Migration Strategy
```bash
# Old approach (multiple namespaces)
kubectl get pods -n metallb-system
kubectl get pods -n ingress-nginx
kubectl get svc -n registry

# New approach (consolidated namespace)
kubectl get all -n hostk8s
kubectl get pods -n hostk8s -l hostk8s.component=metallb
```

### Resource Labeling Convention
```yaml
metadata:
  labels:
    hostk8s.component: metallb    # Component identification
    app.kubernetes.io/name: speaker  # Upstream application name
    app.kubernetes.io/component: speaker  # Upstream component role
```

### Exception Handling
- **kube-system**: Preserved for core Kubernetes components (metrics-server, kube-proxy, etc.)
- **flux-system**: Preserved for GitOps separation of concerns
- **Application namespaces**: Remain isolated per application deployment

## Success Criteria
- Single `kubectl get all -n hostk8s` command shows all infrastructure status
- Resource conflicts eliminated through consistent naming conventions
- Infrastructure addon deployment scripts updated to target `hostk8s` namespace
- Cluster status reporting consolidated into unified infrastructure view
- Cross-platform script parity maintained with namespace updates
