# ADR-004: Extension System Architecture

## Status
**Accepted** - 2025-08-01

## Context
HostK8s needed a way to support complete customization for different use cases and organizations without requiring code changes to the core platform. Users require the ability to add custom cluster configurations, deploy specialized applications, and create domain-specific software stacks while leveraging the HostK8s framework. The solution must be intuitive, support external repositories, and enable dynamic configuration based on environment variables.

## Decision
Implement a **comprehensive extension system** using dedicated `extension/` directories across all platform layers (infrastructure, applications, software stacks) with template processing for dynamic configuration. Extensions operate as first-class citizens alongside built-in components with no code modifications required.

## Rationale
1. **Zero Code Modification**: Complete customization without touching HostK8s core code
2. **First-Class Integration**: Extensions use identical patterns and tooling as built-in components
3. **Dynamic Configuration**: Template processing enables environment-specific customization
4. **External Repository Support**: Extensions can reference and deploy from external Git repositories
5. **Platform Agnostic**: Works for any domain (microservices, enterprise, specialized workloads)
6. **Auto-Detection**: Platform automatically discovers and processes extensions

## Architecture Design

### Extension Directory Structure
```
infra/kubernetes/extension/
├── kind-my-config.yaml          # Custom cluster configurations
└── README.md                    # Extension documentation

software/apps/extension/
├── my-app/
│   ├── app.yaml                 # Application manifests
│   └── README.md               # App documentation
└── README.md                   # Apps extension guide

software/stack/extension/
├── my-stack/
│   ├── kustomization.yaml      # Stack entry point
│   ├── repository.yaml         # GitRepository with template variables
│   ├── stack.yaml             # Component dependencies
│   ├── components/            # Infrastructure Helm releases
│   └── applications/          # Application manifests
└── README.md                  # Stack extension guide
```

### Template Processing Mechanics
Extensions support environment variable substitution using `envsubst`:

```yaml
# software/stack/extension/my-stack/repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: external-stack-system
spec:
  url: ${GITOPS_REPO}           # Substituted at runtime
  ref:
    branch: ${GITOPS_BRANCH}    # Substituted at runtime
  interval: 1m
```

### Auto-Detection Logic
The platform automatically detects extensions:
- **Kind Configs**: `infra/kubernetes/extension/kind-*.yaml` files discovered dynamically
- **Applications**: Any directory in `software/apps/extension/` with `app.yaml`
- **Software Stacks**: Directories in `software/stack/extension/` with `kustomization.yaml`
- **Template Processing**: Applied when stack path contains `extension/`

## Alternatives Considered

### 1. Plugin System with APIs
- **Pros**: Programmatic extension points, rich functionality
- **Cons**: Complex implementation, version compatibility, security concerns
- **Decision**: Rejected due to complexity and maintenance overhead

### 2. Configuration File-Based Extensions
- **Pros**: Simple configuration, structured approach
- **Cons**: Limited flexibility, requires predefined extension points
- **Decision**: Rejected due to flexibility limitations

### 3. Fork-and-Modify Approach
- **Pros**: Complete control, no restrictions
- **Cons**: Loses upstream updates, maintenance burden, no sharing
- **Decision**: Rejected due to maintainability concerns

### 4. Helm Charts Only
- **Pros**: Mature ecosystem, templating capabilities
- **Cons**: Limited to applications, no infrastructure customization
- **Decision**: Rejected due to scope limitations

## Implementation Pattern

### Extension Usage Workflow
```bash
# 1. Custom cluster configuration
export KIND_CONFIG=extension/my-config
make up                              # Uses custom Kind config

# 2. Custom application deployment
make deploy extension/my-app         # Deploys custom application

# 3. External software stack deployment
export GITOPS_REPO=https://github.com/my-org/custom-stack
export GITOPS_BRANCH=develop
make up extension                    # Deploys external stack with template processing
```

### Implementation Approach
The platform uses convention-based detection to automatically discover and process extensions:

- **Template Processing**: Extension files undergo environment variable substitution when path contains `extension/`
- **Auto-Detection**: Platform scans extension directories for standard patterns (kind-*.yaml, app.yaml, kustomization.yaml)
- **Path Resolution**: Direct mapping from command arguments to filesystem locations

## Consequences

**Positive:**
- **Complete Customization**: Users can customize every aspect of the platform without code changes
- **First-Class Experience**: Extensions work identically to built-in components
- **Dynamic Configuration**: Template processing enables environment-specific deployments
- **External Integration**: Support for external repositories and organizations
- **Maintainability**: Extensions isolated from core code, reducing merge conflicts
- **Shareability**: Extensions can be shared across teams and organizations
- **Platform Agnostic**: Works for any domain or specialized use case

**Negative:**
- **Discovery Challenge**: Users need to understand extension directory conventions
- **Template Complexity**: Environmental variable substitution requires careful management
- **Documentation Overhead**: Extensions need their own documentation and examples
- **Testing Complexity**: Extensions require separate validation workflows

## Success Criteria
- Complete platform customization without code modifications
- Template processing works reliably with environment variables
- Auto-detection discovers extensions automatically
- External repository integration functions correctly
- Extensions work identically to built-in components
- Clear separation between core platform and custom extensions

## Related ADRs
- [ADR-001: Host-Mode Architecture](001-host-mode-architecture.md) - Foundation platform architecture
- [ADR-002: Make Interface Standardization](002-make-interface-standardization.md) - Unified interface supporting extensions
- [ADR-003: GitOps Stack Pattern](003-gitops-stack-pattern.md) - Stack pattern extended by extension system
