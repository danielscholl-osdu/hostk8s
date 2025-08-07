# HostK8s Tutorials

Learn HostK8s through a progressive tutorial series that builds from cluster configuration to complete software stacks.

#### [Kind Configuration](cluster.md)
*Beginner | 20-30 minutes*

Learn when and why to customize Kind cluster configurations. Master the key decisions between single-node and multi-node development clusters through practical examples.

**Key Topics:**
- Single-node vs multi-node configuration decisions
- Node roles and workload scheduling
- Storage mounts for persistent data
- Local registry configuration for development
- 3-tier configuration system (temporary, personal, default)

---

#### [Deploying Apps](apps.md)
*Beginner | 30-45 minutes*

Deploy individual applications using HostK8s patterns. This tutorial uses the Docker Voting App as an example to demonstrate fundamental deployment concepts and why individual application deployments don't scale effectively.

**Key Topics:**
- HostK8s application patterns
- Service-to-service communication
- Resource allocation per application
- Limitations of single-app deployments

---

#### [Using Components](shared-components.md)
*Beginner | 20-30 minutes*

Connect applications to pre-built infrastructure components. Learn consumption patterns and service discovery by connecting the voting application to a shared Redis instance.

**Key Topics:**
- Component consumption patterns
- Service discovery mechanisms
- Resource efficiency through sharing
- When to use vs. build components

#### [Building Components](components.md)
*Intermediate | 30-40 minutes*

Design and customize reusable infrastructure services. Explore the Redis Infrastructure Component architecture to understand component patterns and customization options.

**Key Topics:**
- Component design patterns
- Configuration and customization
- Component lifecycle management
- Best practices for reusability

---

#### [Stack Fundamentals](gitops-fundamentals.md)
*Intermediate | 25-35 minutes*

Implement GitOps automation patterns for component orchestration. Build a simple multi-component stack with automated dependency management.

**Key Topics:**
- GitOps principles and benefits
- Dependency management
- Automated deployment workflows
- Configuration as code

#### [Advanced Stacks](stacks.md)
*Advanced | 40-50 minutes*

Compose complete development environments with multiple components and applications. Create a full development stack including container registry and custom applications.

**Key Topics:**
- Stack composition patterns
- Build and deployment workflows
- Environment management
- Production-like development setups
