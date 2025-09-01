# ADR-003: GitOps Stack Pattern

## Status
**Accepted** - 2025-07-28

## Context
HostK8s needed a way to deploy complete, declarative environments that go beyond simple application deployment. Users require consistent patterns for deploying infrastructure components (databases, ingress, certificates) alongside applications, with clear dependency management and environment-specific configurations. The solution must be platform-agnostic and reusable across different domain contexts.

## Decision
Implement the **GitOps Stack Pattern** - a declarative template system for deploying complete environments via Flux, with component/application separation, dual-source repository architecture, and dependency management.

## Rationale
1. **Complete Environments**: Deploy infrastructure + applications as cohesive units
2. **Platform Agnostic**: Pattern works for any software stack (OSDU, microservices, etc.)
3. **Dependency Management**: Clear component ordering and health checks
4. **Repository Separation**: Components and stacks maintained in independent repositories
5. **Reusability**: Stacks can be shared and evolved independently
6. **GitOps Native**: Leverages Flux's reconciliation and drift detection
7. **Selective Sync**: Efficient Git synchronization with ignore patterns
8. **Lifecycle Management**: Standardized labels enable stack-aware operations

## Stack Architecture

### Directory Structure
```
software/stack/
├── bootstrap.yaml         # Universal bootstrap kustomization
└── {stack-name}/          # e.g., sample/, extension/
    ├── kustomization.yaml # Stack entry point
    ├── repository.yaml    # GitRepository source
    ├── stack.yaml         # Component deployments (infrastructure)
    ├── components/        # Infrastructure (Helm releases)
    │   ├── database/      # PostgreSQL
    │   └── ingress-nginx/ # NGINX Ingress
    └── applications/      # Application deployments
        ├── api/           # Sample API service
        └── website/       # Sample website service
```

### Dual-Source Architecture
```
1. Component Source (source-component.yaml)
   ├── COMPONENTS_REPO     # Infrastructure components repository
   ├── COMPONENTS_BRANCH   # Components branch (main/develop)
   └── Syncs: /software/components/

2. Stack Source (source-stack.yaml)
   ├── GITOPS_REPO         # Stack-specific repository
   ├── GITOPS_BRANCH       # Stack branch
   └── Syncs: /software/stacks/{STACK_NAME}/

3. Bootstrap Kustomization (bootstrap.yaml)
   └── Points to specific stack path

4. Stack Kustomization (kustomization.yaml)
   ├── source-component.yaml  # Components GitRepository
   ├── source-stack.yaml      # Stack GitRepository
   └── stack.yaml             # Infrastructure + applications
```

### Deployment Flow
```
1. Component Dependencies (stack.yaml with labels)
   ├── component-certs     # Certificate management
   │   └── labels: hostk8s.stack={name}, hostk8s.type=component
   ├── component-redis     # Redis infrastructure
   │   └── labels: hostk8s.stack={name}, hostk8s.type=component
   └── Sourced from: flux-system (components repo)

2. Applications (stack.yaml with labels)
   ├── app-{stack-name}    # Application deployment
   │   └── labels: hostk8s.stack={name}, hostk8s.type=application
   └── Sourced from: flux-system-{stack-name} (stack repo)

3. Infrastructure Components (/software/components/)
   ├── certs/             # Certificate management via Helm
   └── redis-infrastructure/ # Redis + Commander

4. Applications (/software/stacks/{name}/app/)
   ├── api/              # Stack-specific API
   └── website/          # Stack-specific website
```

## Alternatives Considered

### 1. Helm Charts Only
- **Pros**: Mature ecosystem, templating capabilities
- **Cons**: No GitOps reconciliation, dependency management complex
- **Decision**: Rejected - Helm used within stacks for components only

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

### Dual-Source Integration
```yaml
# source-component.yaml - Infrastructure components
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 5m
  url: ${COMPONENTS_REPO}
  ref:
    branch: ${COMPONENTS_BRANCH}
  ignore: |
    exclude all
    !/software/components/
---
# source-stack.yaml - Stack-specific applications
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system-${SOFTWARE_STACK}
  namespace: flux-system
spec:
  interval: 5m
  url: ${GITOPS_REPO}
  ref:
    branch: ${GITOPS_BRANCH}
  ignore: |
    exclude all
    !/software/stacks/${SOFTWARE_STACK}/
```

### Stack Contract with Labels
```yaml
# stack.yaml - Infrastructure with required labels
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs
  namespace: flux-system
  labels:
    hostk8s.stack: sample          # Stack ownership (required)
    hostk8s.type: component        # Resource type (required)
spec:
  sourceRef:
    kind: GitRepository
    name: flux-system              # Components source
  path: ./software/components/certs
  healthChecks:
    - kind: Secret
      name: root-ca-secret         # Health validation
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app-sample
  namespace: flux-system
  labels:
    hostk8s.stack: sample          # Stack ownership (required)
    hostk8s.type: application      # Resource type (required)
spec:
  dependsOn:
    - name: component-certs        # Explicit dependency ordering
  sourceRef:
    kind: GitRepository
    name: flux-system-sample       # Stack source
  path: ./software/stacks/sample/app
```

### Repository Isolation Benefits
```yaml
# Component Repository (COMPONENTS_REPO)
spec:
  ignore: |
    exclude all
    !/software/components/         # Only infrastructure components

# Stack Repository (GITOPS_REPO)
spec:
  ignore: |
    exclude all
    !/software/stacks/${SOFTWARE_STACK}/  # Only specific stack
```

### Lifecycle Management
```bash
# Stack deployment with dual sources
make up sample                     # Creates both component and stack sources

# Stack removal using labels
make down sample                   # Removes all resources with hostk8s.stack=sample
kubectl delete kustomization -l hostk8s.stack=sample -n flux-system

# Component vs Application isolation
flux get kustomization -l hostk8s.type=component    # Infrastructure only
flux get kustomization -l hostk8s.type=application  # Applications only
```

## Consequences

**Positive:**
- **Environment Consistency**: Identical patterns across dev/staging/prod
- **Platform Agnostic**: Works with any application stack
- **Repository Isolation**: Components and stacks maintained independently
- **Multi-Team Scalability**: Different teams can own infrastructure vs applications
- **Dependency Safety**: Components deploy in correct order with health checks
- **Lifecycle Management**: Stack-aware operations via standardized labels
- **Git Efficiency**: Dual-source selective sync optimizes bandwidth
- **Reusability**: Stacks and components shareable across teams and projects
- **Observability**: Clear GitOps status and reconciliation tracking

**Negative:**
- **Learning Curve**: Developers must understand GitOps and dual-source concepts
- **Debugging Complexity**: Multi-layer abstraction and dual sources complicate troubleshooting
- **Repository Coordination**: Must maintain consistency between component and stack repositories
- **Label Contract Enforcement**: Stack deletion requires proper label application
- **Configuration Complexity**: Additional environment variables for dual-source setup

## Usage Patterns

### Stack Deployment
```bash
make up sample      # Deploy sample stack
make status         # Monitor reconciliation
make sync           # Force reconciliation
flux get all        # Check Flux resources
```

### Stack Development
```bash
# Create new stack
mkdir software/stack/myapp
# Define components, applications, dependencies
# Update bootstrap.yaml to point to new stack
make restart myapp  # Test new stack
```

## Success Criteria
- Complete environment deployment in < 5 minutes
- Component dependency resolution 100% reliable
- Platform-agnostic pattern (works for any software stack)
- Git sync efficiency (ignore patterns significantly reduce sync time)
- Clear observability via `make status` and Flux tools
- Stack reusability across different contexts
