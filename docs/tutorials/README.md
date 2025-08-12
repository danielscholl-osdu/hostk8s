# HostK8s Tutorials

Learn HostK8s through a progressive tutorial series that builds from cluster configuration to complete software stacks.

#### [Cluster Configuration](cluster.md)

Learn configurable cluster architecture patterns that let you version control your development environment alongside your application code. Experience the development workflow trade-offs that drive configuration decisions.

**Key Topics:**
- Configuration-as-code patterns for development environments
- Single-node vs multi-node cluster architecture choices
- Custom Kind configurations for specific development needs
- 3-tier configuration fallback system (named, personal, system defaults)

---

#### [Deploying Applications](apps.md)

Deploy individual applications using HostK8s patterns. Experience the evolution from static YAML limitations to dynamic Helm templates and understand the application contract requirements.

**Key Topics:**
- Application contracts (Kustomization vs Helm chart requirements)
- Multi-namespace deployment with dynamic configuration
- Static YAML limitations vs template flexibility
- Custom values support for local development overrides

---

#### [Software Stacks](stacks.md)

Build complete development environments using GitOps automation. Learn how software stacks eliminate the operational overhead of individual deployments through coordinated component management.

**Key Topics:**
- Stack composition and dependency management
- GitOps deployment automation with Flux
- Component vs application coordination
- Environment consistency and reproducibility

---

#### [Using Components](shared-components.md)

Connect applications to reusable infrastructure components. Learn consumption patterns and service discovery by connecting applications to shared services like Redis and databases.

**Key Topics:**
- Component consumption patterns
- Service discovery mechanisms
- Resource efficiency through sharing
- When to use vs. build components

#### [Building Components](components.md)

Design and customize reusable infrastructure services. Explore component architecture patterns and understand how to create shareable infrastructure building blocks.

**Key Topics:**
- Component design patterns
- Configuration and customization
- Component lifecycle management
- Best practices for reusability
