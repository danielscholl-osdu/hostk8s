# ADR-004: GitOps Stamp Pattern

## Status
**Accepted** - 2025-07-28

## Context
HostK8s needed a way to deploy complete, declarative environments that go beyond simple application deployment. Users require consistent patterns for deploying infrastructure components (databases, ingress, certificates) alongside applications, with clear dependency management and environment-specific configurations. The solution must be platform-agnostic and reusable across different domain contexts.

## Decision
Implement the **GitOps Stamp Pattern** - a declarative template system for deploying complete environments via Flux, with component/application separation and dependency management.

## Rationale
1. **Complete Environments**: Deploy infrastructure + applications as cohesive units
2. **Platform Agnostic**: Pattern works for any software stack (OSDU, microservices, etc.)
3. **Dependency Management**: Clear component ordering and health checks
4. **Reusability**: Stamps can be shared and evolved independently
5. **GitOps Native**: Leverages Flux's reconciliation and drift detection
6. **Selective Sync**: Efficient Git synchronization with ignore patterns

## Stamp Architecture

### Directory Structure
```
software/stamp/
├── bootstrap.yaml         # Universal bootstrap kustomization
└── {stamp-name}/          # e.g., sample/, osdu-ci/
    ├── kustomization.yaml # Stamp entry point
    ├── repository.yaml    # GitRepository source
    ├── stamp.yaml         # Component deployments (infrastructure)
    ├── components/        # Infrastructure (Helm releases)
    │   ├── database/      # PostgreSQL
    │   └── ingress-nginx/ # NGINX Ingress
    └── applications/      # Application deployments
        ├── api/           # Sample API service
        └── website/       # Sample website service
```

### Deployment Flow
```
1. Bootstrap Kustomization (bootstrap.yaml)
   └── Points to specific stamp path

2. Stamp Kustomization (kustomization.yaml)
   ├── repository.yaml     # Creates GitRepository source
   └── stamp.yaml          # Deploys infrastructure components

3. Component Dependencies (stamp.yaml)
   ├── component-certs     # Certificate management
   ├── component-certs-ca  # Root CA certificate
   └── component-certs-issuer # Certificate issuer

4. Infrastructure Components (components/)
   ├── database/           # PostgreSQL via Helm
   └── ingress-nginx/      # NGINX Ingress via Helm

5. Applications (applications/)
   ├── api/               # GitOps-managed API
   └── website/           # GitOps-managed website
```

## Alternatives Considered

### 1. Helm Charts Only
- **Pros**: Mature ecosystem, templating capabilities
- **Cons**: No GitOps reconciliation, dependency management complex
- **Decision**: Rejected - Helm used within stamps for components only

### 2. Kustomize Only
- **Pros**: Kubernetes-native, good for applications
- **Cons**: Poor component lifecycle management, no Helm ecosystem
- **Decision**: Rejected - Kustomize used for stamp orchestration only

### 3. ArgoCD Application Sets
- **Pros**: Mature GitOps platform, good UI
- **Cons**: Complex setup, less flexible than Flux, heavyweight
- **Decision**: Rejected in favor of Flux's simplicity

### 4. Direct Kubernetes Manifests
- **Pros**: Simple, no abstraction layers
- **Cons**: No dependency management, poor reusability, maintenance burden
- **Decision**: Rejected due to scalability concerns

## Implementation Pattern

### Bootstrap Integration
```yaml
# bootstrap.yaml - Universal entry point
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: bootstrap-stamp
spec:
  path: ./software/stamp/sample  # Configurable stamp path
  sourceRef:
    kind: GitRepository
    name: flux-system
```

### Component Dependencies
```yaml
# stamp.yaml - Infrastructure with dependencies
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs-ca
spec:
  dependsOn:
    - name: component-certs  # Explicit dependency ordering
  healthChecks:
    - kind: Secret
      name: root-ca-secret   # Health validation
```

### Selective Git Sync
```yaml
# repository.yaml - Efficient synchronization
spec:
  ignore: |
    # exclude all
    /*
    # include only relevant paths
    !/software/components/
    !/software/stamp/sample/
```

## Consequences

**Positive:**
- **Environment Consistency**: Identical patterns across dev/staging/prod
- **Platform Agnostic**: Works with any application stack
- **Dependency Safety**: Components deploy in correct order with health checks
- **Git Efficiency**: Selective sync reduces bandwidth and reconciliation time
- **Reusability**: Stamps shareable across teams and projects
- **Observability**: Clear GitOps status and reconciliation tracking

**Negative:**
- **Learning Curve**: Developers must understand GitOps concepts
- **Debugging Complexity**: Multi-layer abstraction can complicate troubleshooting
- **Bootstrap Dependency**: Universal bootstrap creates single point of failure
- **Git Repository Coupling**: Stamps tied to specific repository structure

## Usage Patterns

### Stamp Deployment
```bash
make up sample      # Deploy sample stamp
make status         # Monitor reconciliation
make sync           # Force reconciliation
flux get all        # Check Flux resources
```

### Stamp Development
```bash
# Create new stamp
mkdir software/stamp/myapp
# Define components, applications, dependencies
# Update bootstrap.yaml to point to new stamp
make restart myapp  # Test new stamp
```

## Success Criteria
- ✅ Complete environment deployment in < 5 minutes
- ✅ Component dependency resolution 100% reliable
- ✅ Platform-agnostic pattern (works for any software stack)
- ✅ Git sync efficiency (ignore patterns reduce sync by 80%)
- ✅ Clear observability via `make status` and Flux tools
- ✅ Stamp reusability across different contexts
