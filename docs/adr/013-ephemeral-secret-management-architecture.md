# ADR-013: Ephemeral Secret Management Architecture

## Context

Software stacks require sensitive configuration data (database passwords, API keys, tokens) for proper deployment and operation. Traditional approaches either store secrets in Git repositories (security risk) or require manual secret management (operational complexity). Development environments need a solution that provides necessary secrets without compromising security or creating operational burden.

## Decision

Implement ephemeral secret management system using contract-based declarations with automatic generation during stack deployment.

**Core Architecture:**
- **Contract-based declarations** via `hostk8s.secrets.yaml` files in stack directories
- **Ephemeral generation** during stack deployment with no git storage
- **Generic data format** supporting both static values and generated secrets
- **Cross-platform implementation** with functional parity between .sh/.ps1 scripts
- **Automatic lifecycle integration** as part of `make up <stack>` workflow

**Key Components:**
1. **Secret Contracts** - YAML declarations of required secrets using generic `data:` field format
2. **Generation Engine** - Cross-platform scripts supporting password, token, hex, and UUID generation
3. **Lifecycle Integration** - Automatic secret generation after stack deployment
4. **Namespace Sequencing** - Wait for Flux-created namespaces before secret generation

## Rationale

**Why Ephemeral Generation:**
- **Security**: No sensitive data stored in repositories
- **Environment Isolation**: Different secrets per cluster/environment
- **Development Velocity**: No manual secret management required
- **Reproducibility**: Identical secret generation across environments

**Why Contract-based Approach:**
- **Declarative**: Secrets as code without storing actual values
- **Self-documenting**: Clear declaration of secret requirements
- **Version Control**: Contract changes tracked in Git
- **Validation**: Automated verification of secret requirements

**Why Generic Data Format:**
- **Simplicity**: Single, consistent schema for all secret types
- **Flexibility**: Supports both static values and multiple generation types
- **Maintainability**: No complex type-specific templates
- **Extensibility**: Easy to add new generation types

**Why Integrated Lifecycle:**
- **Developer Experience**: Secrets automatically available after `make up`
- **Sequencing**: Proper order (deploy stack → wait for namespace → generate secrets)
- **Idempotency**: Existing secrets preserved, new secrets generated
- **Error Handling**: Graceful fallback if secret generation fails

## Implementation

### Contract Schema
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
        - key: {field-name}
          value: {static-value}        # Static values
          generate: {generation-type}  # Generated values
          length: {length}             # Optional for generated
```

### Generation Types
- `password`: Alphanumeric + symbols (secure passwords)
- `token`: Alphanumeric only (API tokens)
- `hex`: Hexadecimal characters (keys, IDs)
- `uuid`: UUID format (correlation IDs)

### Cross-Platform Scripts
- **Bash**: `infra/scripts/manage-secrets.sh`
- **PowerShell**: `infra/scripts/manage-secrets.ps1`
- **Functional Parity**: Identical behavior across platforms
- **Common Interface**: `manage-secrets.{sh|ps1} <stack-name>`

### Lifecycle Integration
```makefile
up: ## Deploy software stack
    @$(SCRIPT_RUNNER) ./infra/scripts/deploy-stack$(SCRIPT_EXT) $(stack)
    @$(SCRIPT_RUNNER) ./infra/scripts/manage-secrets$(SCRIPT_EXT) $(stack) 2>/dev/null || true
```

### Security Features
- **No Git Storage**: Secrets never written to repository
- **Cluster-only Existence**: Secrets live only in Kubernetes
- **Proper Labeling**: `hostk8s.io/managed: "true"` and `hostk8s.io/contract: "<stack>"`
- **Cryptographically Secure**: Using platform-native secure random generation
- **Idempotent Operations**: Existing secrets preserved

## Consequences

### Positive
- **Security Enhancement**: Zero sensitive data in repositories
- **Development Velocity**: Automatic secret provisioning eliminates manual steps
- **Environment Consistency**: Identical secret generation across all platforms
- **Operational Simplicity**: Single command deploys stack with all required secrets
- **Debugging Simplicity**: Standard Kubernetes secret commands work normally
- **GitOps Compatible**: Contracts tracked in Git, values generated at runtime

### Negative
- **Secret Regeneration Complexity**: Deleting secrets requires understanding of regeneration timing
- **Cross-Platform Maintenance**: Dual script implementation requires synchronization
- **Limited Generation Types**: Only basic generation patterns supported initially
- **Namespace Dependency**: Requires proper sequencing with Flux namespace creation
- **Platform Tool Dependencies**: Requires `yq` for YAML parsing on all platforms

### Risk Mitigation
- **Testing Strategy**: Comprehensive cross-platform validation in CI/CD
- **Documentation**: Clear secret contract specifications and examples
- **Fallback Handling**: Graceful failure if secret generation encounters issues
- **Tool Installation**: Automatic `yq` installation via platform package managers

## Alternatives Considered

**External Secret Management (HashiCorp Vault, AWS Secrets Manager):**
- **Rejected**: Adds infrastructure complexity and external dependencies to development environments
- **Use Case**: More appropriate for production environments

**Encrypted Secrets in Git (sealed-secrets, SOPS):**
- **Rejected**: Still stores sensitive data in repositories, requires key management
- **Complexity**: Additional tooling and key rotation procedures

**Manual Secret Management:**
- **Rejected**: Creates operational burden and "works on my machine" problems
- **Scaling Issues**: Becomes unmanageable with multiple stacks and developers

**Built-in Kubernetes Secrets:**
- **Rejected**: No automatic generation, requires manual creation and management
- **Limited Functionality**: No cross-platform generation capabilities

## Related ADRs

- **[ADR-001](001-host-mode-architecture.md)**: Host-mode architecture enables direct cluster access for secret management
- **[ADR-002](002-make-interface-standardization.md)**: Make interface provides consistent secret management commands
- **[ADR-003](003-gitops-stack-pattern.md)**: GitOps stack pattern provides deployment lifecycle for secret integration
- **[ADR-009](009-cross-platform-implementation-strategy.md)**: Cross-platform strategy applied to secret management scripts

---

**Status**: Accepted
**Date**: 2025-09-02
**Decision Makers**: Platform Architecture Team
**Scope**: Secret management for all HostK8s software stacks
