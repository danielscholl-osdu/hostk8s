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
│  │    • Persistent Data Architecture                       ││
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

1. **Make Interface Layer** - Standardized commands with cross-platform OS detection (`install`, `start`, `stop`, `up`, `down`, `restart`, `clean`, `status`)
2. **Script Orchestration Layer** - Platform-native scripts (.sh/.ps1) managing specific operations with functional parity
3. **Common Utilities Layer** - Platform-specific utilities (common.sh/common.ps1) ensuring consistent behavior across operating systems

For example, when you run `make start`, the Make interface detects the OS and selects the appropriate script (.sh or .ps1), the orchestration layer handles the Kind configuration, and the platform-specific utilities layer manages KUBECONFIG setup and provides consistent logging—all transparently across Unix/Linux/Mac/Windows.

This strategy delivers complexity abstraction, automatic environment management, cross-platform consistency, and clean separation of concerns. (Design decision rationale in [ADR-002](adr/002-make-interface-standardization.md))

### Dependencies and Tool Integration

The platform integrates with four essential tools, automatically installed using platform-native package managers to ensure consistent environments:

- **Kind** for cluster creation and management
- **kubectl** for Kubernetes API interaction
- **Helm** for package management
- **Docker** as the container runtime foundation

**Platform-Specific Installation:**
- **Unix/Linux/Mac**: brew, apt, yum, and other native package managers
- **Windows**: winget (preferred) with chocolatey fallback

This integration approach eliminates manual dependency management while preserving standard Kubernetes tooling compatibility across all platforms.

### Cluster Lifecycle Management

**Managed Lifecycle Approach:**
The platform treats cluster operations as a managed lifecycle rather than ad-hoc commands. Development clusters progress through predictable phases:

- **Creation** - Dependency validation and configuration selection
- **Validation** - Ensuring cluster meets operational requirements
- **Iteration** - Fast reset capabilities for development cycles
- **Cleanup** - Proper resource deallocation

**Configuration Strategy:**
Cluster configurations use a 3-tier fallback system optimized for progressive user experience:

1. **KIND_CONFIG Override** (Explicit Control)
   - `KIND_CONFIG=kind-custom.yaml make start` - Direct file specification
   - `KIND_CONFIG=minimal make start` - Alternative configurations
   - Used for testing, CI/CD, and advanced scenarios

2. **kind-config.yaml** (Personal Customization)
   - Auto-detected user configuration file (gitignored)
   - Created by copying from examples: `cp infra/kubernetes/kind-custom.yaml infra/kubernetes/kind-config.yaml`
   - Persistent custom setup for individual developers

3. **Functional Defaults** (Zero Configuration)
   - Automatically uses kind-custom.yaml for complete functionality
   - Includes port mappings, registry support, and ingress capabilities
   - Ensures tutorials and examples work out of the box with `make start`

This strategy eliminates configuration barriers for new users while providing complete customization for advanced workflows (detailed in [ADR-007](adr/007-kind-configuration-fallback-system.md)).
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

### Source Code Build System Architecture

**The Development Iteration Problem:**
Modern development workflows require rapid build-test-deploy cycles within Kubernetes environments. Developers need to containerize and deploy source code changes quickly without complex CI/CD setup for local development.

**The Solution:**
The platform provides a comprehensive source code build system through `make build src/APP_NAME`, supporting multiple programming languages and automatic integration with the cluster container registry.

**Key Capabilities:**
- **Multi-Language Support** - Node.js, Python, Java, C#/.NET applications
- **Container-Native Builds** - Docker Compose integration for consistent, reproducible builds
- **Cluster Registry Integration** - Automatic push to localhost:5000 registry for immediate deployment
- **Educational Progression** - Simple to complex examples (registry-demo → sample-app → example-voting-app)
- **Development Velocity** - Fast iteration cycles for source code changes

**Build System Workflow:**
```bash
make build src/sample-app        # Build all services and push to cluster registry
make deploy voting-app           # Deploy using built containers
make status                      # Verify deployment
# Edit source code, repeat cycle
```

**Architecture Integration:**
The build system integrates seamlessly with the GitOps stack pattern - applications can be built locally and deployed via standard Kubernetes manifests, maintaining consistency between development and production workflows. (Detailed design in [ADR-008](adr/008-source-code-build-system.md))

### Vault-Integrated Secret Management Architecture

**The Development Security Challenge:**
Software stacks require sensitive configuration data (database passwords, API keys, tokens) for proper deployment and operation. Traditional approaches either store secrets in Git repositories (security risk) or require manual secret management (operational complexity). Direct Kubernetes secret generation creates race conditions with GitOps namespace creation.

**The Solution:**
The platform provides a Vault-integrated secret management system using HashiCorp Vault + External Secrets Operator (ESO) while preserving contract-based declarations. This eliminates race conditions and aligns with modern GitOps practices.

**Key Capabilities:**
- **Contract-Based Declarations** - YAML contracts (`hostk8s.secrets.yaml`) declaring secret requirements
- **Vault Backend Storage** - HashiCorp Vault (dev mode) stores generated secrets securely
- **External Secrets Operator** - Syncs secrets from Vault to Kubernetes declaratively
- **GitOps Integration** - ExternalSecret manifests deployed via Flux eliminate timing dependencies
- **Development UI** - Vault web interface for secret inspection and debugging
- **Enhanced Lifecycle** - Command-based interface (add/remove/list) for complete secret management

**Secret Management Workflow:**
```bash
# Stack declares secret requirements in hostk8s.secrets.yaml
make up sample-app              # Store secrets in Vault + generate ExternalSecret manifests
git add software/stacks/sample-app/manifests/external-secrets.yaml
git commit -m "Add external secrets for sample-app"
# Flux deploys ExternalSecrets → ESO syncs from Vault → Kubernetes secrets created
kubectl get secrets -n sample-app  # View synchronized secrets
```

**Contract Example (Unchanged):**
```yaml
# software/stacks/sample-app/hostk8s.secrets.yaml
apiVersion: hostk8s.io/v1
kind: SecretContract
metadata:
  name: sample-app
spec:
  secrets:
    - name: postgres-credentials
      namespace: sample-app
      data:
        - key: username
          value: postgres
        - key: password
          generate: password
          length: 8
        - key: host
          value: voting-db-rw.sample-app.svc.cluster.local
```

**Generated ExternalSecret Example:**
```yaml
# software/stacks/sample-app/manifests/external-secrets.yaml (safe to commit)
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: postgres-credentials
  namespace: sample-app
spec:
  refreshInterval: 10s
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: postgres-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: sample-app/sample-app/postgres-credentials
      property: username
```

**Architecture Integration:**
The Vault-integrated system eliminates race conditions by storing secrets in Vault and using declarative ExternalSecret manifests deployed via Flux. This aligns with GitOps principles while maintaining security - contracts and ExternalSecret manifests are stored in Git, while actual secret values exist only in Vault and Kubernetes. (Evolution detailed in [ADR-014](adr/014-vault-integrated-secret-management-architecture.md), original foundation in [ADR-013](adr/013-ephemeral-secret-management-architecture.md))

### Extensibility Architecture

**The Innovation Challenge:**
Default scenarios provide immediate value but quickly become restrictive barriers to innovation. As systems grow in complexity, the operational overhead increases exponentially—managing dependencies, coordinating deployments, and debugging interactions becomes increasingly difficult. While comprehensive software stacks offer deep capabilities, developers need flexibility to integrate, modify, experiment, and build upon existing foundations without being constrained by rigid implementations.

**Abstraction Framework Solution:**
The platform's common abstraction framework ensures that operational complexity remains constant regardless of stack sophistication or application complexity. Whether deploying a simple web app or a complex distributed system with multiple databases, message queues, and microservices, the developer experience remains `make build`, `make deploy`, `make up <stack>` the framework handles the underlying orchestration complexity transparently.

**Extension Points as Interfaces:**
The platform treats extensibility as a **contract-based architecture**. Extension points function as defined interfaces, the platform provides orchestration capabilities while users provide implementations that adhere to established contracts.

For example:
- `make deploy <my_app>` works with any application following the deployment contract (standardized manifest structure)
- `make build src/<my_app>` can build any application with a defined build contract (docker-compose.yml structure), automatically pushing to the cluster registry
- `make up <my_stack>` deploys any software stack meeting the stack contract (kustomization structure, dependency definitions)
- `make start [config]` creates clusters using any Kind configuration following the platform's naming conventions

**Separation of Platform and User Concerns:**
This contract-based approach enables **zero-coupling extensibility**. You can build, deploy, and orchestrate applications without their code being directly related to the platform codebase. The platform handles environment management, orchestration, and lifecycle operations while users focus on their specific domain implementations.

**Innovation Enablement:**
Extension points preserve the platform's automation benefits while enabling:
- **Creative experimentation** with new technologies and patterns
- **Rapid iteration** on custom configurations and workflows
- **Integration flexibility** for external systems and existing stacks
- **Debugging capabilities** for complex, domain-specific scenarios

(Contract specifications and design rationale in [ADR-004](adr/004-extension-system-architecture.md))

### Infrastructure Addon Architecture

**The Development Infrastructure Challenge:**
Local Kubernetes development requires supporting infrastructure (load balancers, ingress controllers, container registries, metrics collection) that operates reliably across cluster lifecycle events. Traditional approaches using individual namespaces create operational complexity and discovery challenges in development environments.

**Addon vs Software Component Distinction:**
The platform distinguishes between **infrastructure addons** (platform foundation services) and **software components** (application-supporting services). Infrastructure addons provide core platform capabilities and are managed as part of the cluster lifecycle, while software components are deployed via GitOps as part of application stacks.

**Infrastructure Addon Principles:**
- **Unified Namespace Strategy** - All infrastructure addons deploy to `hostk8s` namespace for operational simplicity
- **Environment-Driven Configuration** - Enable/disable via environment variables (METALLB_ENABLED, INGRESS_DISABLED, etc.)
- **Cross-Platform Script Parity** - Unified Python scripts via `uv` for all addon setup scripts
- **Lifecycle Integration** - Addon setup integrated into cluster startup sequence
- **Component Labeling** - Consistent resource labels (`hostk8s.component: <name>`) for identification

**Addon Integration Pattern:**
```python
# cluster-up.py integration pattern (Python-based)
def run_addon_script(self, script_name: str) -> bool:
    """Run an addon setup script (Python-only for OS independence)."""
    python_script = self.script_dir / f'{script_name}.py'
    if python_script.exists() and shutil.which('uv'):
        logger.info(f"[Script 🐍] Running script: [cyan]{script_name}.py[/cyan]")
        try:
            env = os.environ.copy()
            env['KUBECONFIG'] = str(self.kubeconfig_path)
            result = subprocess.run(['uv', 'run', str(python_script)],
                                  env=env, check=False)
            return result.returncode == 0
        except Exception as e:
            logger.debug(f"Error running Python script: {e}")
            return False

    logger.warn(f"{script_name}.py script not found, skipping")
    return False

# Usage in setup_addons()
if self.addon_enabled:
    if not self.run_addon_script('setup-addon'):
        logger.warn("[Cluster] Addon setup failed, continuing")
```

**Core Infrastructure Addons:**

**MetalLB LoadBalancer**
- **Purpose**: Provides LoadBalancer service type functionality in development clusters
- **Deployment**: Unified `hostk8s` namespace with custom IP pool configuration
- **Integration**: Automatic detection by ingress controllers for LoadBalancer service creation

**NGINX Ingress Controller**
- **Purpose**: HTTP/HTTPS ingress capabilities with localhost port mapping
- **Deployment**: `hostk8s` namespace with MetalLB integration or NodePort fallback
- **Configuration**: Automatic service type selection based on MetalLB availability

**HashiCorp Vault Secret Management**
- **Purpose**: Centralized secret storage for development environments with External Secrets Operator integration
- **Deployment**: Dev mode configuration in `hostk8s` namespace with token-based authentication
- **Integration**: Web UI via NGINX ingress, ClusterSecretStore for ESO, dependency-aware startup sequencing
- **Configuration**: Automatic setup when `VAULT_ENABLED=true`, includes ESO installation and ClusterSecretStore creation

**Hybrid Container Registry**
- **Purpose**: Local image storage and deployment for development workflows
- **Architecture**: Docker container API + Kubernetes UI deployment with ingress proxy
- **Integration**: Containerd configuration for Kind nodes, NGINX ingress for web UI

**Metrics Server**
- **Purpose**: Resource metrics collection for `kubectl top` functionality
- **Deployment**: Standard `kube-system` namespace following Kubernetes conventions
- **Configuration**: Kind-specific settings for kubelet certificate handling

**Architectural Benefits:**
- **Operational Simplification** - Single namespace discovery point for infrastructure
- **Development Velocity** - Fast cluster creation with complete infrastructure
- **Cross-Platform Consistency** - Identical functionality across Mac, Linux, Windows
- **Resource Efficiency** - Consolidated resource allocation and monitoring
- **Debugging Simplicity** - Unified infrastructure status and troubleshooting

(Design decisions detailed in [ADR-010](adr/010-infrastructure-addon-namespace-consolidation.md) and [ADR-011](adr/011-hybrid-container-registry-architecture.md))

## Integration Architecture

### Filesystem Plugin Architecture

The platform implements a **filesystem-based plugin architecture** using .gitignore patterns to create clean separation between platform code and custom applications:

```
software/apps/
├── .gitignore              # Excludes all content except built-in apps
├── README.md               # Documentation preserved
├── simple/                 # Built-in app (platform-maintained)
├── sample/                 # Built-in app (platform-maintained)
├── my-custom-app/          # External repository (team-maintained, ignored)
└── team-prototype/         # Custom app (ignored by git)
```

**Repository Isolation Strategy:** The apps directory uses `*` .gitignore patterns with explicit inclusions for built-in apps (`!simple/`, `!sample/`), meaning teams can clone entire external repositories or create custom applications directly in `software/apps/` without affecting the main platform repository. This enables **independent development** where teams maintain separate version control while the platform provides unified deployment infrastructure.

### Convention-Based Discovery Pattern

The platform uses **convention-over-configuration** for seamless integration of both local and external extensions:

```
make deploy my-app                  →  maps to software/apps/my-app/kustomization.yaml
make build src/my-app               →  maps to src/my-app/
git clone <external-repo> my-app    →  immediately available in software/apps/
```

**Path Resolution:** The platform uses direct path-based routing to locate apps - `my-app` maps directly to `software/apps/my-app/`, regardless of whether apps originate from the main repository, external clones, or manual file placement. The .gitignore system controls which apps are tracked by the repository.

### Dual Integration Patterns

The platform uses **different integration strategies** for different extension types, optimized for their specific architectural requirements:

**Filesystem-Based Extensions:**
- **Cluster Configurations:** `KIND_CONFIG=my-config` → `infra/kubernetes/kind-my-config.yaml` *(custom configurations in main directory)*
- **Source Code Builds:** `make build src/my-app` → `src/my-app/` (build and push to cluster registry)
- **Application Deployments:** `make deploy my-app` → `software/apps/my-app/kustomization.yaml` *(simplified path)*


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

This dual approach enables **extension isolation** at both filesystem (individual components) and repository (complete environments) levels. For applications, the .gitignore-based system provides clean separation between built-in and custom apps without requiring nested directory structures.

### Template Processing Integration

For external system integration, the platform uses **environment variable substitution** to enable dynamic configuration without hardcoding values:

```yaml
# Extension repository.yaml
spec:
  url: ${GITOPS_REPO}           # Dynamically configured
  ref:
    branch: ${GITOPS_BRANCH}    # Release specific
```

**Conditional Template Processing:** The platform automatically applies `envsubst` template processing to software stack files from external repositories while applying core platform files directly without processing, enabling parameterized extensions without affecting platform stability. Application-level extensions use the .gitignore system and don't require special template processing.


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
make start minimal       # Create lightweight validation cluster
make status              # Validate functionality
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

### ADR Summaries

**[ADR-001: Host-Mode Architecture](adr/001-host-mode-architecture.md)**
- **Decision**: Use Kind directly on host Docker daemon, eliminating Docker-in-Docker complexity
- **Benefits**: Stability, faster startup, lower resource usage, standard kubectl/kind workflow
- **Tradeoffs**: Less isolation, Docker Desktop dependency, single-node limitation

**[ADR-002: Make Interface Standardization](adr/002-make-interface-standardization.md)**
- **Decision**: Implement standardized Make interface wrapping all operational scripts with consistent conventions
- **Benefits**: Universal familiarity, standard conventions, automatic KUBECONFIG handling, discoverability
- **Tradeoffs**: Abstraction layer, Make dependency, argument limitations

**[ADR-003: GitOps Stack Pattern](adr/003-gitops-stack-pattern.md)**
- **Decision**: Implement stack pattern for deploying complete environments via Flux with dual-source architecture and component/application separation
- **Benefits**: Repository isolation, multi-team scalability, complete environments, platform agnostic, lifecycle management
- **Tradeoffs**: Learning curve, repository coordination, debugging complexity, configuration complexity

**[ADR-004: Extension System Architecture](adr/004-extension-system-architecture.md)**
- **Decision**: Implement comprehensive extension system using dedicated extension/ directories with template processing for dynamic configuration
- **Benefits**: Complete customization, first-class experience, dynamic configuration, external integration
- **Tradeoffs**: Discovery challenge, template complexity, documentation overhead, testing complexity

**[ADR-005: AI-Assisted Development Integration](adr/005-ai-assisted-development-integration.md)**
- **Decision**: Integrate optional AI-assisted development capabilities through three-layer architecture (MCP servers, specialized subagents, automated hooks)
- **Benefits**: Productivity multiplier, optional enhancement, extensible architecture, domain specialization
- **Tradeoffs**: Architectural complexity, current AI service dependency, learning curve

**[ADR-006: Temporary Hybrid CI/CD Workaround](adr/006-hybrid-ci-cd-strategy.md)**
- **Decision**: Temporary workaround using GitLab CI for validation then triggering GitHub Actions for Kubernetes testing due to GitLab runner limitations
- **Benefits**: Preserves GitLab workflow, accesses GitHub K8s tooling, smart change detection
- **Tradeoffs**: Operational complexity, dual platform dependency, temporary solution

**[ADR-007: Kind Configuration 3-Tier Fallback System](adr/007-kind-configuration-fallback-system.md)**
- **Decision**: Implement 3-tier fallback system for Kind cluster configuration prioritizing user experience progression
- **Benefits**: Simplified onboarding, progressive complexity, flexible customization, clean repository
- **Tradeoffs**: Slightly more complex logic, potential tier confusion, migration required

**[ADR-008: Source Code Build System Architecture](adr/008-source-code-build-system.md)**
- **Decision**: Comprehensive source code build system enabling developers to build, containerize, and deploy applications directly from source code
- **Benefits**: Rapid development velocity, multi-language support, educational value, registry integration, GitOps compatibility
- **Tradeoffs**: Build dependencies, registry complexity, disk usage, build time, platform dependencies

**[ADR-009: Cross-Platform Implementation Strategy](adr/009-cross-platform-implementation-strategy.md)**
- **Decision**: Implement dual script architecture with functional parity between platform-native scripts (.sh/.ps1) rather than cross-platform scripting solutions
- **Benefits**: Native platform integration, developer familiarity, performance, architecture preservation, feature parity
- **Tradeoffs**: Dual maintenance burden, functional parity verification, testing complexity, synchronization risk

**[ADR-010: Infrastructure Addon Namespace Consolidation](adr/010-infrastructure-addon-namespace-consolidation.md)**
- **Decision**: Consolidate infrastructure addons into unified hostk8s namespace while preserving component isolation through labels and resource naming conventions
- **Benefits**: Operational simplicity, developer productivity, unified resource management, simplified RBAC
- **Tradeoffs**: Deviation from upstream conventions, reduced namespace isolation, naming conflict risk

**[ADR-011: Hybrid Container Registry Architecture](adr/011-hybrid-container-registry-architecture.md)**
- **Decision**: Adopt hybrid container registry architecture combining Docker container deployment for registry API with Kubernetes deployment for web UI, connected through ingress proxy
- **Benefits**: Reliability, CORS elimination, container-native performance, persistent storage, debugging access
- **Tradeoffs**: Architectural complexity, hybrid deployment pattern, network configuration overhead, documentation complexity

**[ADR-012: Host-Mode Data Persistence Architecture](adr/012-host-mode-data-persistence-architecture.md)**
- **Decision**: Organized host-mode data persistence using dedicated directory structure with service-specific isolation and Kind extraMounts integration
- **Benefits**: Data persistence, service isolation, stack organization, debugging access, cross-platform consistency
- **Tradeoffs**: Directory complexity, host filesystem dependency, manual cleanup, storage capacity limits

**[ADR-013: Ephemeral Secret Management Architecture](adr/013-ephemeral-secret-management-architecture.md)**
- **Decision**: Implement ephemeral secret management system using contract-based declarations with automatic generation during stack deployment
- **Benefits**: Security enhancement, development velocity, environment consistency, operational simplicity, GitOps compatibility
- **Tradeoffs**: Cross-platform maintenance, limited generation types, namespace dependency, platform tool dependencies

**[ADR-014: Vault-Integrated Secret Management Architecture](adr/014-vault-integrated-secret-management-architecture.md)**
- **Decision**: Evolve secret management to use HashiCorp Vault + External Secrets Operator while preserving SecretContract format
- **Benefits**: Race condition elimination, GitOps compliance, development UI, operational resilience, architecture modernization
- **Tradeoffs**: Infrastructure complexity, startup dependencies, development learning curve, manual Git workflow
