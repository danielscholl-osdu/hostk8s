# HostK8s Architecture

## Problem Statement

HostK8s solves the development environment complexity problem by running Kubernetes clusters directly on your local Docker daemon. This host-mode architecture eliminates the performance overhead and operational complexity of traditional cloud-based or VM-based development environments.

**The Development Environment Challenge:**
Developers need production-like Kubernetes environments for testing, but traditional solutions create barriers:
- Cloud environments require shared resource allocation, introduce network dependencies, and lock teams into specific provider ecosystems
- VM-based solutions consume excessive local resources
- Docker-in-Docker approaches create stability and networking complexity
- Manual environment setup leads to "works on my machine" problems

**Host-Mode Solution:**
Host-mode runs Kubernetes clusters directly on your local Docker daemon, providing:
- Dedicated per-developer environments without operational overhead
- Direct container access for debugging
- Faster startup and lower resource usage
- Complete cloud vendor neutrality
- Reproducible environments through declarative configuration

## Core Architectural Decisions

HostK8s is built on three foundational architectural decisions (detailed rationale in [ADR-001](adr/001-host-mode-architecture.md), [ADR-002](adr/002-make-interface-standardization.md), [ADR-003](adr/003-gitops-stack-pattern.md)):

1. **Host-Mode Execution**: Use Kind directly on host Docker daemon rather than nested virtualization
2. **Abstraction Interface**: Provide familiar Make commands that hide operational complexity
3. **Software Stack Pattern**: Deploy complete environments rather than individual applications

These decisions work together to create a platform that prioritizes developer productivity while maintaining production-like capabilities.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Development Environment                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Interactive   │  │   Automated     │  │   Testing    │ │
│  │   Development   │  │   Validation    │  │   Workflows  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│           │                  │                    │         │
│        Familiar           Hybrid               Comprehensive│
│        Commands           Strategy             Validation   │
└─────────────────────────────────────────────────────────────┘
                           │
                  Abstraction Interface
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              HostK8s Platform Architecture                  │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                Make Interface Layer                     ││
│  │             (Standardized Commands)                     ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │             Script Orchestration Layer                  ││
│  │           (Lifecycle Management)                        ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Common Utilities Layer                     ││
│  │            (Shared Operations)                          ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
                  Host-Mode Integration
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                Host Docker Environment                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │           Kubernetes Development Cluster                ││
│  │    • Direct Container Access (No Nested Virtualization) ││
│  │    • Progressive Complexity (Minimal → Full Featured)   ││
│  │    • Software Stack Deployments                         ││
│  │    • Extension Points for Customization                 ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                           │
                  Transparent Integration
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                Developer Experience                         │
│  • Standard Kubernetes Tooling (kubectl, helm, flux)        │
│  • Automatic Environment Management                         │
│  • Progressive Service Access (NodePort → LoadBalancer)     │
│  • Extension Points for Custom Workflows                    │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### Three-Layer Abstraction Strategy

The platform simplifies complex Kubernetes operations through a three-layer abstraction:

1. **Make Interface Layer** - Standardized commands engineers recognize (`install`, `up`, `down`, `test`, `clean`)
2. **Script Orchestration Layer** - Single-responsibility scripts managing specific operations
3. **Common Utilities Layer** - Shared functions ensuring consistent behavior (logging, error handling, environment management)

For example, when you run `make up`, the Make interface validates dependencies, the orchestration layer selects the appropriate Kind configuration, and the utilities layer handles KUBECONFIG setup and provides consistent logging—all transparently.

This strategy delivers complexity abstraction, automatic environment management, and clean separation of concerns. (Design decision rationale in [ADR-002](adr/002-make-interface-standardization.md))

### Dependencies and Tool Integration

The platform integrates with four essential tools, automatically installed to ensure consistent environments:

- **Kind** for cluster creation and management
- **kubectl** for Kubernetes API interaction
- **Helm** for package management
- **Docker** as the container runtime foundation

This integration approach eliminates manual dependency management while preserving standard Kubernetes tooling compatibility.

### Cluster Lifecycle Management

**Managed Lifecycle Approach:**
The platform treats cluster operations as a managed lifecycle rather than ad-hoc commands. Development clusters progress through predictable phases:

- **Creation** - Dependency validation and configuration selection
- **Validation** - Ensuring cluster meets operational requirements
- **Iteration** - Fast reset capabilities for development cycles
- **Cleanup** - Proper resource deallocation

**Configuration Strategy:**
Cluster configurations follow a progressive complexity model:
- **Minimal → Simple → Default** - Increasing capability presets
- **CI-optimized** - Specialized for automated testing environments
- **Extension Points** - Custom configurations without core platform modification

**Operational Consistency:**
All lifecycle phases share common operational patterns through shared utilities, enabling individual component testing while maintaining system-wide behavioral consistency.



### Software Stack Architecture

**The Problem:**
Microservice applications require multiple supporting services (databases, message queues, ingress controllers). Managing these dependencies individually creates complexity and inconsistency.

**The Solution:**
Software stacks deploy complete, coherent environments rather than individual applications. Each stack represents a fully functional technology environment.

**Key Principles:**
- **Component/Application Separation** - Infrastructure and applications deployed independently with proper dependency management
- **Declarative Composition** - Complete environments defined as code
- **Bootstrap Pattern** - Universal entry point for any stack configuration
- **Convention-Based Discovery** - Automatic detection and deployment of stack components

**Implementation Approach:**
Stacks use GitOps patterns with Flux for continuous deployment, enabling complete environment reproducibility and version control. (Detailed design in [ADR-003](adr/003-gitops-stack-pattern.md))

### Extensibility Architecture

**The Innovation Challenge:**
Default scenarios provide immediate value but quickly become restrictive barriers to innovation. As systems grow in complexity, the operational overhead increases exponentially—managing dependencies, coordinating deployments, and debugging interactions becomes increasingly difficult. While comprehensive software stacks offer deep capabilities, developers need flexibility to integrate, modify, experiment, and build upon existing foundations without being constrained by rigid implementations.

**Abstraction Framework Solution:**
The platform's common abstraction framework ensures that operational complexity remains constant regardless of stack sophistication or application complexity. Whether deploying a simple web app or a complex distributed system with multiple databases, message queues, and microservices, the developer experience remains `make build`, `make deploy`, `make up` the framework handles the underlying orchestration complexity transparently.

**Extension Points as Interfaces:**
The platform treats extensibility as a **contract-based architecture**. Extension points function as defined interfaces, the platform provides orchestration capabilities while users provide implementations that adhere to established contracts.

For example:
- `make deploy <my_app>` works with any application following the deployment contract (standardized manifest structure)
- `make build <my_app>` can build any application with a defined build contract (docker-compose, Dockerfile, etc.), automatically pushing to the cluster registry
- `make up <my_stack>` deploys any software stack meeting the stack contract (kustomization structure, dependency definitions)

**Separation of Platform and User Concerns:**
This contract-based approach enables **zero-coupling extensibility**. You can build, deploy, and orchestrate applications without their code being directly related to the platform codebase. The platform handles environment management, orchestration, and lifecycle operations while users focus on their specific domain implementations.

**Innovation Enablement:**
Extension points preserve the platform's automation benefits while enabling:
- **Creative experimentation** with new technologies and patterns
- **Rapid iteration** on custom configurations and workflows
- **Integration flexibility** for external systems and existing stacks
- **Debugging capabilities** for complex, domain-specific scenarios

(Contract specifications and design rationale in [ADR-004](adr/004-extension-system-architecture.md))


## Integration Architecture

### Filesystem Plugin Architecture

The platform implements a **filesystem-based plugin architecture** using .gitignore patterns to create clean separation between platform code and extension code:

```
extension/
├── .gitignore          # Excludes all content except samples
├── README.md           # Documentation preserved
├── sample-extension/   # Example extension (platform-maintained)
└── my-team-extension/  # External repository (team-maintained)
```

**Repository Isolation Strategy:** Extension directories use `*` .gitignore patterns, meaning teams can clone entire external repositories into these locations without affecting the main platform repository. This enables **independent development** where extension teams maintain separate version control while the platform provides integration infrastructure.

### Convention-Based Discovery Pattern

The platform uses **convention-over-configuration** for seamless integration of both local and external extensions:

```
make deploy extension/my-app        →  maps to extension/my-app/app.yaml
make build src/extension/my-app     →  maps to src/extension/my-app/
git clone <external-repo> extension/my-app  →  immediately available
```

**Path Resolution:** The platform uses direct path-based routing to locate extension files - `extension/my-app` maps directly to the filesystem location, regardless of whether extensions originate from the main repository, external clones, or manual file placement.

### Dual Integration Patterns

The platform uses **different integration strategies** for different extension types, optimized for their specific architectural requirements:

**Filesystem-Based Extensions:**
- **Cluster Configurations:** `KIND_CONFIG=extension/sample` → `infra/kubernetes/extension/kind-sample.yaml`
- **Source Code Builds:** `make build src/extension/my-app` → `src/extension/my-app/` (build and push to cluster registry)
- **Application Deployments:** `make deploy extension/sample` → `software/apps/extension/sample/app.yaml`


**Git Repository-Based Extensions:**
- **Software Stacks:** Complete environments sourced from external repositories via Flux GitRepository resources. Each stack can reference different repositories and branches:
  ```bash
  export GITOPS_REPO=https://gitlab.com/team-a/software-stack
  export GITOPS_BRANCH=main
  make up extension  # Deploys complete stack from external repository
  ```

**Stack Composition Architecture:**
Multiple teams can develop independent stacks that compose into larger environments:
- **Stack A** (component) from `gitlab.com/team-a/software-stack-a`
- **Stack B** (applications) from `gitlab.com/team-b/software-stack-b` (depends on Stack A)
- **Independent versioning** with cross-stack dependency management via GitOps

This dual approach enables **extension isolation** at both filesystem (individual components) and repository (complete environments) levels.

### Template Processing Integration

For external system integration, the platform uses **environment variable substitution** to enable dynamic configuration without hardcoding values:

```yaml
# Extension repository.yaml
spec:
  url: ${GITOPS_REPO}           # Dynamically configured
  ref:
    branch: ${GITOPS_BRANCH}    # Release specific
```

**Conditional Template Processing:** The platform automatically applies `envsubst` template processing to extension files (path contains `"extension/"`) while applying core platform files directly without processing, enabling parameterized extensions without affecting platform stability.


## Integration Points

### CI/CD Enablement Architecture

**Platform Capabilities for CI/CD**

HostK8s provides architectural primitives that enable sophisticated CI/CD patterns without mandating specific implementations:

**Built-in Quality Validation:**
- **YAML Linting** - Platform includes .yamllint configuration and pre-commit hooks for complex YAML validation
- **Pre-commit Framework** - Implemented hooks for local validation (format checking, lint enforcement, standards compliance)
- **CI Integration Examples** - Basic Kind cluster creation and validation using built-in samples
- **Make Interface Consistency** - Uniform commands across different CI/CD systems

**Ephemeral Testing Capabilities:**

The platform's lightweight architecture enables CI/CD systems to implement **disposable test environments**:
```bash
# CI/CD systems can leverage these patterns
make up minimal          # Create lightweight validation cluster
make test                # Validate functionality
make clean               # Destroy environment
```

**Architectural Enablement:**
- **Isolation Capabilities** - Kind's container-based architecture enables independent test environments
- **Resource Efficiency** - Fast cluster creation/destruction enables parallel testing strategies
- **Stack Composition Testing** - Software stack pattern enables testing complex dependencies
- **Composable Validation** - Platform primitives support modular testing approaches

**Future CI/CD Potential:**

This architecture enables CI/CD systems to move away from **dedicated monolithic testing infrastructure** toward **composable, isolated validation** patterns, though implementation remains the responsibility of individual CI/CD configurations.

**Integration Capabilities**

The platform integrates with existing CI/CD systems through standard tooling compatibility. KUBECONFIG, networking, and tool configuration are handled transparently, enabling standard Kubernetes tooling (`kubectl`, `helm`, `flux`) to work seamlessly in automated environments.


---

## Architecture Decision Records

For detailed rationale behind key design choices, see our Architecture Decision Records:

### ADR Index

| id  | title                               | status | details |
| --- | ----------------------------------- | ------ | ------- |
| 001 | Host-Mode Architecture              | acc    | [ADR-001](adr/001-host-mode-architecture.md) |
| 002 | Make Interface Standardization     | acc    | [ADR-002](adr/002-make-interface-standardization.md) |
| 003 | GitOps Stack Pattern               | acc    | [ADR-003](adr/003-gitops-stack-pattern.md) |
| 004 | Extension System Architecture       | acc    | [ADR-004](adr/004-extension-system-architecture.md) |
| 005 | AI-Assisted Development Integration | acc    | [ADR-005](adr/005-ai-assisted-development-integration.md) |
| 006 | Hybrid CI/CD Strategy              | temp   | [ADR-006](adr/006-hybrid-ci-cd-strategy.md) |

### ADR Summaries

**ADR-001: Host-Mode Architecture**
- **Decision**: Use Kind directly on host Docker daemon, eliminating Docker-in-Docker complexity
- **Benefits**: Stability, 50% faster startup, lower resource usage (4GB vs 8GB), standard kubectl/kind workflow
- **Tradeoffs**: Less isolation, Docker Desktop dependency, single-node limitation

**ADR-002: Make Interface Standardization**
- **Decision**: Implement standardized Make interface wrapping all operational scripts with consistent conventions
- **Benefits**: Universal familiarity, standard conventions, automatic KUBECONFIG handling, discoverability
- **Tradeoffs**: Abstraction layer, Make dependency, argument limitations

**ADR-003: GitOps Stack Pattern**
- **Decision**: Implement stack pattern for deploying complete environments via Flux with component/application separation
- **Benefits**: Complete environments, platform agnostic, dependency management, reusability
- **Tradeoffs**: Learning curve, debugging complexity, bootstrap dependency

**ADR-004: Extension System Architecture**
- **Decision**: Implement comprehensive extension system using dedicated extension/ directories with template processing for dynamic configuration
- **Benefits**: Complete customization, first-class experience, dynamic configuration, external integration
- **Tradeoffs**: Discovery challenge, template complexity, documentation overhead, testing complexity

**ADR-005: AI-Assisted Development Integration**
- **Decision**: Integrate optional AI-assisted development capabilities through three-layer architecture (MCP servers, specialized subagents, automated hooks)
- **Benefits**: Productivity multiplier, optional enhancement, extensible architecture, domain specialization
- **Tradeoffs**: Architectural complexity, current AI service dependency, learning curve

**ADR-006: Temporary Hybrid CI/CD Workaround**
- **Decision**: Temporary workaround using GitLab CI for validation then triggering GitHub Actions for Kubernetes testing due to GitLab runner limitations
- **Benefits**: Preserves GitLab workflow, accesses GitHub K8s tooling, smart change detection
- **Tradeoffs**: Operational complexity, dual platform dependency, temporary solution

Each ADR documents the context, decision, alternatives considered, and consequences - providing the "why" behind HostK8s's unique architecture.

---

## Navigation

- **← [Back to README](../README.md)** - Getting started guide
- **→ [AI-Assisted Development](ai-assisted-development.md)** - Optional AI capabilities and usage scenarios
- **→ [ADR Catalog](adr/README.md)** - All architecture decisions
- **→ [Sample Apps](../software/apps/README.md)** - Available applications
