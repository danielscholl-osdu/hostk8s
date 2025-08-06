# HostK8s Tutorials

Learn HostK8s through a progressive tutorial series that builds from individual applications to complete software stacks.

## Learning Path

**Complexity:** 🟢 Beginner • 🔵 Intermediate • 🟠 Advanced

### Applications
### 🟢 **[Deploying Apps](apps.md)**
Learn to deploy individual applications like the Docker Voting App. Master basic HostK8s application patterns and understand the building blocks philosophy.

### Components
### 🟢 **[Using Shared Components](shared-components.md)**
Learn to use pre-built HostK8s components and connect applications to shared infrastructure services. Focus on consumption patterns, not creation.

### 🔵 **[Building Components](components.md)**
Understand HostK8s component design patterns and learn to customize reusable infrastructure services. Focus on patterns, not manual YAML creation.

### Stacks
### 🔵 **[GitOps Fundamentals](gitops-fundamentals.md)**
Learn GitOps automation patterns and understand how HostK8s orchestrates components automatically.

### 🟠 **[Software Stacks](stacks.md)**
Compose complete development environments combining multiple components and applications with full GitOps automation.


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
