# HostK8s Tutorials

Learn HostK8s through a progressive tutorial series that builds from individual applications to complete software stacks.

## Learning Path

### Applications

#### [Deploying Apps](apps.md) 🟢
*Beginner | 30-45 minutes*

Deploy individual applications using HostK8s patterns. This tutorial uses the Docker Voting App as an example to demonstrate fundamental deployment concepts and why individual application deployments don't scale effectively.

**Key Topics:**
- HostK8s application patterns
- Service-to-service communication
- Resource allocation per application
- Limitations of single-app deployments

---

### Components

#### [Using Shared Components](shared-components.md) 🟢
*Beginner | 20-30 minutes*

Connect applications to pre-built infrastructure components. Learn consumption patterns and service discovery by connecting the voting application to a shared Redis instance.

**Key Topics:**
- Component consumption patterns
- Service discovery mechanisms
- Resource efficiency through sharing
- When to use vs. build components

#### [Building Components](components.md) 🔵
*Intermediate | 30-40 minutes*

Design and customize reusable infrastructure services. Explore the Redis Infrastructure Component architecture to understand component patterns and customization options.

**Key Topics:**
- Component design patterns
- Configuration and customization
- Component lifecycle management
- Best practices for reusability

---

### Stacks

#### [GitOps Fundamentals](gitops-fundamentals.md) 🔵
*Intermediate | 25-35 minutes*

Implement GitOps automation patterns for component orchestration. Build a simple multi-component stack with automated dependency management.

**Key Topics:**
- GitOps principles and benefits
- Dependency management
- Automated deployment workflows
- Configuration as code

#### [Software Stacks](stacks.md) 🟠
*Advanced | 40-50 minutes*

Compose complete development environments with multiple components and applications. Create a full development stack including container registry and custom applications.

**Key Topics:**
- Stack composition patterns
- Build and deployment workflows
- Environment management
- Production-like development setups

## Tutorial Progression

```
🟢 Apps → 🟢 Use Components → 🔵 Build Components → 🔵 GitOps → 🟠 Complete Stacks
```

### The Building Blocks Journey

**Applications**: See all the pieces - understand what you're abstracting
**Components**: Use shared pieces → Understand the patterns
**Stacks**: Automate deployment → Complete environments

## Tutorial Features

### 🔗 **Connected Learning**
Each tutorial builds on concepts from previous tutorials:
- Apps tutorial sets up individual application patterns
- Components tutorial shows how to share infrastructure between apps
- Stacks tutorial combines components and apps into complete environments

### 🛠️ **Hands-On Practice**
- Build real applications and infrastructure
- Deploy to actual Kubernetes clusters
- Verify functionality through web interfaces and command line

### 📋 **Progressive Complexity**
- Start with simple, single-purpose deployments
- Add shared infrastructure and resource optimization
- Complete with production-like GitOps automation

### 🎯 **Practical Focus**
- Use realistic examples (voting app, Redis infrastructure)
- Demonstrate real-world patterns and best practices
- Show immediate, tangible results through web UIs

## Quick Start

**Get started with any tutorial:**

```bash
# Clone and setup HostK8s
git clone https://community.opengroup.org/danielscholl/hostk8s.git
cd hostk8s
make install

# Start basic cluster
make start

# Start with Applications tutorial
# Then progress through Components and Stacks
```

## Tutorial Support

- **Architecture context**: [Architecture Guide](../architecture.md)
- **AI assistance**: [AI Guide](../ai-guide.md)
- **Troubleshooting**: Each tutorial includes troubleshooting sections
- **Commands reference**: All tutorials use standard HostK8s `make` commands

---

**Ready to start?** Begin with [🟢 Deploying Apps](apps.md)
