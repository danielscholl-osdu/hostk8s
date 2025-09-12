# ADR-007: Kind Configuration 3-Tier Fallback System

## Status
Accepted

## Context

HostK8s requires flexible Kubernetes cluster configuration to support different user experience levels and use cases:

- **Beginners** need simple setup without configuration complexity
- **Regular users** want persistent custom configurations for their workflow
- **Advanced users** need explicit configuration control for testing and special scenarios

The previous system required users to understand and manage Kind configuration files from the start, creating a barrier to entry. It also lacked a clear upgrade path from simple to advanced usage.

## Decision

We implement a 3-tier fallback system for Kind cluster configuration:

### Tier 1: Environment Variable Override (Highest Priority)
```bash
KIND_CONFIG=kind-custom.yaml make start
KIND_CONFIG=extension/my-config make start
```
- Explicit configuration control
- Used for testing, CI/CD, and special scenarios
- Overrides all other configuration sources

### Tier 2: User Custom Configuration (Medium Priority)
```bash
# Create persistent custom config
cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml
# Edit kind-config.yaml as needed
make start
```
- Personal configuration file: `infra/kubernetes/kind-config.yaml`
- Gitignored for user-specific customization
- Used when present, ignored when absent

### Tier 3: Functional Defaults (Fallback)
```bash
make start  # Uses kind-custom.yaml automatically
```
- Automatically uses kind-custom.yaml for complete functionality
- Includes port mappings, registry support, and ingress capabilities
- Ensures all tutorials and examples work out of the box

## Rationale

### User Experience Benefits
- **Progressive Complexity**: Natural upgrade path from simple → custom → advanced
- **Zero Configuration**: New users get working clusters immediately
- **Flexible Customization**: Advanced users get full control without complexity for others
- **Clear Mental Model**: Explicit priority system is easy to understand

### Technical Benefits
- **Consistent Patterns**: Follows similar fallback patterns used in apps and stacks
- **Maintainability**: No default configuration files to keep in sync
- **Clean Repository**: Gitignored user configs don't clutter version control
- **Testing Flexibility**: Environment overrides enable consistent CI/CD

### Implementation Details
```bash
# Decision logic in infra/scripts/cluster-up.py
if [ -n "${KIND_CONFIG}" ]; then
    # Use explicit environment variable
    KIND_CONFIG_PATH="infra/kubernetes/${KIND_CONFIG_FILE}"
elif [ -f "infra/kubernetes/kind-config.yaml" ]; then
    # Use user's custom configuration
    KIND_CONFIG_PATH="infra/kubernetes/kind-config.yaml"
else
    # Use functional defaults (kind-custom.yaml)
    KIND_CONFIG_PATH="infra/kubernetes/kind-custom.yaml"
fi
```

## Alternatives Considered

### Single Required Configuration
- **Rejected**: Creates barriers for beginners
- **Rejected**: Requires maintaining a "default" config in version control

### Environment Variable Only
- **Rejected**: Requires explicit configuration for every invocation
- **Rejected**: No persistent customization for regular users

### Two-Tier System (No Defaults)
- **Rejected**: Still requires configuration knowledge for basic usage
- **Rejected**: Would break tutorials and examples for new users

## Consequences

### Positive
- **Simplified Onboarding**: New users can immediately run `make start`
- **Reduced Documentation Burden**: Less explanation needed for basic usage
- **Better Development Workflow**: Developers can easily switch between configurations
- **Consistent UX**: Aligns with other HostK8s fallback patterns

### Negative
- **Slightly More Complex Logic**: Requires 3-tier decision logic in scripts
- **Potential Confusion**: Users might not know which tier is active without debug output
- **Migration Required**: Existing users need to rename their configuration files

### Mitigation
- Debug logging shows which configuration tier is active
- Clear documentation explains all three tiers with examples
- Migration is simple: rename `kind-config.yaml` to `kind-custom.yaml`

## Examples

### Beginner Usage
```bash
# Just works - uses kind-custom.yaml automatically
# Includes all features needed for tutorials
make start
```

### Regular User Workflow
```bash
# One-time setup
cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml
vim infra/kubernetes/kind-config.yaml  # Customize as needed

# Always uses custom config
make start
```

### Advanced/CI Usage
```bash
# Explicit control for different scenarios
KIND_CONFIG=kind-custom.yaml make start          # Full features
KIND_CONFIG=kind-config-minimal.yaml make start  # Minimal setup
KIND_CONFIG=extension/gpu-enabled make start     # Custom extension
```

## Related ADRs
- [ADR-002: Make Interface Standardization](002-make-interface-standardization.md) - Establishes the `make start` interface
- [ADR-004: Extension System Architecture](004-extension-system-architecture.md) - Uses `KIND_CONFIG=extension/name` pattern

## References
- Kind Configuration Documentation: https://kind.sigs.k8s.io/docs/user/configuration/
- HostK8s Configuration Guide: ../tutorials/configuration.md
