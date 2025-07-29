# ADR Catalog

Optimized ADR Index for Agent Context

## Index

| id  | title                               | status | details |
| --- | ----------------------------------- | ------ | ------- |
| 001 | Host-Mode Architecture              | acc    | [ADR-001](001-host-mode-architecture.md) |
| 002 | Make Interface Standardization     | acc    | [ADR-002](002-make-interface-standardization.md) |
| 003 | GitOps Stamp Pattern               | acc    | [ADR-003](003-gitops-stamp-pattern.md) |
| 004 | Hybrid CI/CD Strategy              | acc    | [ADR-004](004-hybrid-ci-cd-strategy.md) |

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
• Standard conventions: make up/test/clean patterns developers expect
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
