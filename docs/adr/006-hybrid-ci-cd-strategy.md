# ADR-006: Temporary Hybrid CI/CD Workaround

## Status
**Temporary** - 2025-07-28
*This is a temporary solution until GitLab CI capabilities improve*

## Context
HostK8s requires comprehensive testing of Kubernetes environments, GitOps reconciliation, and cross-platform compatibility. GitLab CI, while suitable for basic validation tasks, currently lacks the runner capabilities and Kubernetes tooling ecosystem needed for complex cluster testing and GitOps validation. However, the development workflow is centered on GitLab, making a pure GitHub Actions solution suboptimal for developer experience.

## Decision
Implement a **temporary hybrid CI/CD workaround** where GitLab CI handles validation and code synchronization, then triggers GitHub Actions for comprehensive Kubernetes testing. This preserves GitLab-centered workflow while accessing GitHub's superior Kubernetes testing capabilities.

## Rationale
1. **GitLab Limitations**: Current GitLab runners insufficient for complex Kubernetes testing
2. **Preserve Workflow**: Maintain GitLab-centered development experience
3. **Access Superior Tooling**: GitHub Actions ecosystem better suited for Kubernetes validation
4. **Smart Resource Usage**: Skip expensive testing for documentation-only changes
5. **Temporary Solution**: Bridge until GitLab capabilities improve or alternative found

## Implementation Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitLab CI (Primary)                      │
│  • YAML validation                                          │
│  • Makefile syntax checks                                   │
│  • Code synchronization to GitHub                           │
│  • Smart change detection                                   │
└─────────────────────────────────────────────────────────────┘
                           │
                    Triggers via API
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│               GitHub Actions (Kubernetes Testing)           │
│  • Kind cluster creation and testing                        │
│  • Flux GitOps reconciliation validation                    │
│  • Multi-environment testing scenarios                      │
│  • Status reporting back to GitLab                          │
└─────────────────────────────────────────────────────────────┘
```

### Current Implementation Details
- **GitLab CI Role**: Basic validation, code sync, change detection, GitHub trigger
- **GitHub Actions Role**: Kubernetes cluster testing, GitOps validation
- **Smart Triggering**: Documentation-only changes skip expensive Kubernetes tests
- **Status Integration**: GitHub results appear in GitLab commit status

## Alternatives Considered

### 1. GitLab CI Only
- **Pros**: Single platform, native workflow integration
- **Cons**: Insufficient runner capabilities for Kubernetes testing
- **Decision**: Rejected due to technical limitations (current reason for this ADR)

### 2. GitHub Actions Only
- **Pros**: Excellent Kubernetes tooling, powerful runners
- **Cons**: Disrupts GitLab-centered development workflow
- **Decision**: Rejected due to workflow impact

### 3. Self-Hosted GitLab Runners
- **Pros**: Full control over runner capabilities
- **Cons**: Infrastructure overhead, maintenance burden, cost
- **Decision**: Rejected due to operational complexity

### 4. Third-Party CI/CD Service
- **Pros**: Specialized Kubernetes testing capabilities
- **Cons**: Additional vendor relationship, workflow fragmentation
- **Decision**: Rejected due to complexity

## Consequences

**Positive:**
- Preserves GitLab-centered developer workflow
- Accesses GitHub's superior Kubernetes testing ecosystem
- Smart change detection reduces unnecessary test runs
- Maintains comprehensive GitOps validation capabilities

**Negative:**
- Operational complexity managing two platforms
- Additional failure points in the pipeline
- Dependency on both GitLab and GitHub service availability
- Learning curve for developers troubleshooting cross-platform issues
- Code synchronization latency between platforms

**Neutral:**
- Temporary nature means this complexity will be resolved
- Platform consolidation planned when GitLab capabilities improve

## Migration Strategy

**Goal**: Consolidate to GitLab CI when technically feasible

**Triggers for Migration:**
- GitLab runner capabilities improve for Kubernetes testing
- GitLab CI/CD ecosystem develops better Kubernetes tooling
- Self-hosted runner option becomes viable
- Alternative single-platform solution identified

**Success Criteria for Migration:**
- Single platform can handle all testing requirements
- No loss of testing comprehensiveness
- Equivalent or better developer experience
- Reduced operational complexity

## Current Status Assessment
- GitLab CI handles validation and workflow integration effectively
- GitHub Actions provides necessary Kubernetes testing capabilities
- Smart change detection prevents unnecessary test runs
- Status integration maintains unified developer experience
- Solution is functional but adds operational overhead

## Future Considerations
This hybrid approach is explicitly temporary. Regular reassessment is needed to identify opportunities for platform consolidation as GitLab CI capabilities evolve or alternative solutions emerge.

## Related ADRs
- [ADR-001: Host-Mode Architecture](001-host-mode-architecture.md) - Foundation platform architecture
- [ADR-003: GitOps Stack Pattern](003-gitops-stack-pattern.md) - GitOps workflows being tested
