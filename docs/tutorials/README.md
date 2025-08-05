# HostK8s Tutorials

Learn HostK8s through a progressive tutorial series that builds from individual applications to complete software stacks.

## Learning Path

### 📚 **Level 100: [Deploying Apps](apps.md)**
*30-45 minutes | Beginner*

Learn to deploy individual applications like the Docker Voting App. Master basic HostK8s application patterns, multi-service deployment, and Kubernetes fundamentals.

**You'll Build:** Complete voting application with 5 interconnected services
**You'll Learn:** Application structure, service communication, NodePort access
**Foundation For:** Understanding individual applications before learning shared services

### 🔧 **Level 200: [Shared Components](components.md)**
*45-60 minutes | Intermediate*

Build reusable infrastructure services that multiple applications can share. Create a Redis infrastructure component with management UI and integrate it with existing applications.

**You'll Build:** Redis Infrastructure Component (server + Commander UI + persistence)
**You'll Learn:** Component architecture, shared service patterns, resource efficiency
**Foundation For:** Understanding infrastructure building blocks for complete stacks

### 🏗️ **Level 300: [Software Stacks](stacks.md)**
*60+ minutes | Advanced*

Orchestrate complete development environments combining multiple components and applications using GitOps automation with Flux.

**You'll Build:** Complete development environment with shared components and multiple apps
**You'll Learn:** GitOps workflows, stack composition, environment management
**Foundation For:** Production-like development environments

## Tutorial Progression

```
Individual Apps  →  Shared Components  →  Complete Stacks
     ↓                    ↓                    ↓
Vote, Result,      Redis Component      GitOps-managed
Worker, DB         (shared by apps)     Environment
Redis (per app)         +                    +
                 Commander UI          Multiple Apps
                      +                      +
                 Persistence           Automated Deploy
```

## Prerequisites

- **Docker Desktop** v4.0+ with 4GB+ RAM
- **Basic container concepts** (images, containers, networking)
- **Command line familiarity** (bash commands, text editing)

**All Kubernetes tools installed automatically** via `make install`

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

# Choose your tutorial level:
# Level 100: Follow Apps tutorial
# Level 200: Follow Components tutorial (after Apps)
# Level 300: Follow Stacks tutorial (after Components)
```

## Tutorial Support

- **Architecture context**: [Architecture Guide](../architecture.md)
- **AI assistance**: [AI Guide](../ai-guide.md)
- **Troubleshooting**: Each tutorial includes troubleshooting sections
- **Commands reference**: All tutorials use standard HostK8s `make` commands
