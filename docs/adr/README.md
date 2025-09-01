# ADR Catalog

Optimized ADR Index for Agent Context

## Index

| id  | title                               | status | details |
| --- | ----------------------------------- | ------ | ------- |
| 001 | Host-Mode Architecture              | acc    | [ADR-001](001-host-mode-architecture.md) |
| 002 | Make Interface Standardization      | acc    | [ADR-002](002-make-interface-standardization.md) |
| 003 | GitOps Stack Pattern                | acc    | [ADR-003](003-gitops-stack-pattern.md) |
| 004 | Extension System Architecture       | acc    | [ADR-004](004-extension-system-architecture.md) |
| 005 | AI-Assisted Development Integration | acc    | [ADR-005](005-ai-assisted-development-integration.md) |
| 006 | Hybrid CI/CD Strategy               | acc    | [ADR-006](006-hybrid-ci-cd-strategy.md) |
| 007 | Kind Configuration Fallback System | acc    | [ADR-007](007-kind-configuration-fallback-system.md) |
| 008 | Source Code Build System Architecture | acc    | [ADR-008](008-source-code-build-system.md) |
| 009 | Cross-Platform Implementation Strategy | acc    | [ADR-009](009-cross-platform-implementation-strategy.md) |
| 010 | Infrastructure Addon Namespace Consolidation | acc    | [ADR-010](010-infrastructure-addon-namespace-consolidation.md) |
| 011 | Hybrid Container Registry Architecture | acc    | [ADR-011](011-hybrid-container-registry-architecture.md) |
| 012 | Host-Mode Data Persistence Architecture | acc    | [ADR-012](012-host-mode-data-persistence-architecture.md) |

---

## ADR Records

--------------------------------------------
```yaml
id: 001
title: Host-Mode Architecture
status: accepted
date: 2025-01-10
decision: Use Kind directly on host Docker daemon, eliminating Docker-in-Docker complexity.
why: |
• Stability: eliminates Docker Desktop hanging issues
• Performance: 50% faster startup, lower resource usage (4GB vs 8GB)
• Simplicity: standard kubectl/kind workflow
• Reliability: predictable cross-platform behavior
tradeoffs:
positive: [stability, performance, resource efficiency, simplicity]
negative: [less isolation, Docker Desktop dependency, single-node limitation]
```

--------------------------------------------
```yaml
id: 002
title: Make Interface Standardization
status: accepted
date: 2025-01-15
decision: Implement standardized Make interface wrapping all operational scripts with consistent conventions.
why: |
• Universal familiarity: Make available on all platforms
• Standard conventions: make start/test/clean patterns developers expect
• Environment management: automatic KUBECONFIG handling
• Discoverability: self-documenting help system
tradeoffs:
positive: [developer experience, error prevention, consistency, discoverability]
negative: [abstraction layer, Make dependency, argument limitations]
```

--------------------------------------------
```yaml
id: 003
title: GitOps Stamp Pattern
status: accepted
date: 2025-01-18
decision: Implement stamp pattern for deploying complete environments via Flux with component/application separation.
why: |
• Complete environments: infrastructure + applications as cohesive units
• Platform agnostic: works for any software stack (OSDU, microservices, etc.)
• Dependency management: clear component ordering and health checks
• Reusability: stamps shareable across teams and projects
tradeoffs:
positive: [environment consistency, platform agnostic, dependency safety, reusability]
negative: [learning curve, debugging complexity, bootstrap dependency]
```

--------------------------------------------
```yaml
id: 004
title: Extension System Architecture
status: accepted
date: 2025-08-01
decision: Implement comprehensive extension system using dedicated extension/ directories with template processing for dynamic configuration.
why: |
• Zero code modification: Complete customization without touching HostK8s core
• First-class integration: Extensions work identically to built-in components
• Dynamic configuration: Template processing enables environment-specific customization
• External repository support: Extensions can reference external Git repositories
• Platform agnostic: Works for any domain or specialized use case
tradeoffs:
positive: [complete customization, first-class experience, dynamic configuration, external integration]
negative: [discovery challenge, template complexity, documentation overhead, testing complexity]
```

--------------------------------------------
```yaml
id: 005
title: AI-Assisted Development Integration
status: accepted
date: 2025-07-30
decision: Integrate optional AI-assisted development capabilities through three-layer architecture (MCP servers, specialized subagents, automated hooks).
why: |
• Productivity multiplier: AI reduces time for complex GitOps debugging and cluster analysis
• Optional enhancement: Zero impact on users preferring traditional workflows
• Multi-tool compatibility: Works with Claude Code, GitHub Copilot, and other MCP-enabled assistants
• Domain specialization: Targeted AI agents for HostK8s workflows
• Quality automation: Professional standards enforcement without manual oversight
tradeoffs:
positive: [productivity enhancement, optional adoption, multi-tool support, domain expertise]
negative: [architectural complexity, AI service dependency, learning curve]
```

--------------------------------------------
```yaml
id: 006
title: Hybrid CI/CD Strategy
status: accepted
date: 2025-01-20
decision: Branch-aware hybrid CI/CD combining GitLab CI (fast) with GitHub Actions (comprehensive).
why: |
• Fast feedback (2-3 min) for development velocity
• Comprehensive testing (8-10 min) for production readiness
• Branch-aware: PR branches get minimal, main gets full testing
• Resource optimization avoids expensive tests on every commit
tradeoffs:
positive: [dev velocity, comprehensive coverage, resource efficiency]
negative: [dual platform complexity, sync overhead]
```

--------------------------------------------
```yaml
id: 007
title: Kind Configuration Fallback System
status: accepted
date: 2025-08-07
decision: Implement 3-tier fallback system for Kind cluster configuration prioritizing user experience progression.
why: |
• Progressive complexity: Natural upgrade path from simple → custom → advanced
• Zero configuration: New users get working clusters with full functionality automatically
• Flexible customization: Advanced users get full control without complexity for others
• Clear mental model: Explicit priority system is easy to understand and debug
tradeoffs:
positive: [simplified onboarding, progressive complexity, flexible customization, clean repository]
negative: [slightly more complex logic, potential tier confusion, migration required]
```

--------------------------------------------
```yaml
id: 008
title: Source Code Build System Architecture
status: accepted
date: 2025-08-08
decision: Implement comprehensive source code build system enabling developers to build, containerize, and deploy applications directly from source code using make build src/APP_NAME.
why: |
• Development velocity: Enable rapid iteration on source code within Kubernetes environments
• Multi-language support: Accommodate diverse development stacks (Node.js, Python, Java, C#, etc.)
• Container-native: Leverage Docker Compose for consistent, reproducible builds
• Registry integration: Automatic push to cluster registry for immediate deployment
• Educational value: Provide complete examples for learning different technology stacks
tradeoffs:
positive: [rapid development, multi-language support, educational excellence, registry integration, GitOps compatibility]
negative: [build dependencies, registry complexity, disk usage, build time, platform dependencies]
```

--------------------------------------------
```yaml
id: 009
title: Cross-Platform Implementation Strategy
status: accepted
date: 2025-01-15
decision: Implement dual script architecture with functional parity between platform-native scripts (.sh/.ps1) rather than cross-platform scripting solutions.
why: |
• Platform optimization: Native tooling integration (winget/chocolatey vs brew/apt) provides better user experience
• Developer familiarity: Platform-specific scripting conventions align with developer expectations
• Performance: No abstraction layer overhead; scripts execute in optimal platform environments
• Architecture preservation: Maintains successful three-layer abstraction while extending platform support
tradeoffs:
positive: [native platform integration, developer familiarity, performance, architecture preservation, feature parity]
negative: [dual maintenance burden, functional parity verification, testing complexity, synchronization risk]
```

--------------------------------------------
```yaml
id: 010
title: Infrastructure Addon Namespace Consolidation
status: accepted
date: 2025-08-29
decision: Consolidate infrastructure addons into unified hostk8s namespace while preserving component isolation through labels and resource naming conventions.
why: |
• Operational simplification: Single discovery point for all infrastructure components
• Developer experience: Reduced cognitive load and simplified kubectl commands
• Resource organization: Logical grouping of infrastructure with shared lifecycle
• RBAC simplification: Single namespace reduces permission complexity for development
tradeoffs:
positive: [operational simplicity, developer productivity, unified resource management, simplified RBAC]
negative: [deviation from upstream conventions, reduced namespace isolation, naming conflict risk]
```

--------------------------------------------
```yaml
id: 011
title: Hybrid Container Registry Architecture
status: accepted
date: 2025-08-29
decision: Adopt hybrid container registry architecture combining Docker container deployment for registry API with Kubernetes deployment for web UI, connected through ingress proxy.
why: |
• Container-native reliability: Docker registry runs natively on host daemon, eliminating orchestration overhead
• CORS resolution: Ingress proxy eliminates cross-origin requests by serving UI and API from same origin
• Containerd integration: Direct Kind node configuration for seamless image pulling
• Persistent storage: Host directory mounting survives cluster recreate/restart operations
tradeoffs:
positive: [reliability, CORS elimination, container-native performance, persistent storage, debugging access]
negative: [architectural complexity, hybrid deployment pattern, network configuration overhead, documentation complexity]
```

--------------------------------------------
```yaml
id: 012
title: Host-Mode Data Persistence Architecture
status: accepted
date: 2025-09-01
decision: Adopt organized host-mode data persistence architecture using dedicated directory structure with service-specific isolation and Kind extraMounts integration.
why: |
• Service isolation: Dedicated directories for each infrastructure service prevent conflicts
• Stack organization: Stack-specific directories under data/pv/ enable multi-environment isolation
• Cross-cluster survival: Data persists across cluster recreation and development iterations
• Host-mode integration: Direct filesystem access with standardized mount point contracts
• Developer experience: Clear directory structure with predictable application integration patterns
tradeoffs:
positive: [data persistence, service isolation, stack organization, debugging access, cross-platform consistency]
negative: [directory complexity, host filesystem dependency, manual cleanup, storage capacity limits]
```
