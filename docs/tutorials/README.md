# HostK8s Tutorials

Learn HostK8s through a progressive tutorial series that builds from individual applications to complete software stacks.

## Learning Path

### 📚 **Level 100: [Deploying Apps](apps.md)**
*30-45 minutes | Beginner*

Learn to deploy individual applications like the Docker Voting App. Master basic HostK8s application patterns and understand the building blocks philosophy.

**You'll Build:** Complete voting application with 5 interconnected services
**You'll Learn:** HostK8s patterns, service communication, why individual apps don't scale
**Foundation For:** Understanding building blocks before learning to share them

### 🔧 **Level 150: [Using Shared Components](shared-components.md)**
*20-30 minutes | Beginner-Intermediate*

Learn to use pre-built HostK8s components and connect applications to shared infrastructure services. Focus on consumption patterns, not creation.

**You'll Build:** Voting app connected to shared Redis component
**You'll Learn:** Component consumption, service discovery, resource efficiency
**Foundation For:** Understanding how components work before building them

### 🏗️ **Level 200: [Building Components](components.md)**
*30-40 minutes | Intermediate*

Understand HostK8s component design patterns and learn to customize reusable infrastructure services. Focus on patterns, not manual YAML creation.

**You'll Build:** Understanding of Redis Infrastructure Component architecture
**You'll Learn:** Component patterns, customization, when to build vs use existing
**Foundation For:** Creating building blocks for software stacks

### ⚡ **Level 250: [GitOps Fundamentals](gitops-fundamentals.md)**
*25-35 minutes | Intermediate-Advanced*

Learn GitOps automation patterns and understand how HostK8s orchestrates components automatically.

**You'll Build:** Simple 2-3 component automated stack
**You'll Learn:** GitOps concepts, dependency management, automation benefits
**Foundation For:** Complex software stack orchestration

### 🚀 **Level 300: [Software Stacks](stacks.md)**
*40-50 minutes | Advanced*

Compose complete development environments combining multiple components and applications with full GitOps automation.

**You'll Build:** Complete development environment with registry and custom apps
**You'll Learn:** Stack composition, build workflows, environment management
**Foundation For:** Production-like development environments

## Tutorial Progression

```
Individual Apps → Use Components → Build Components → GitOps → Complete Stacks
   (Level 100)     (Level 150)      (Level 200)    (Level 250)  (Level 300)
       ↓               ↓                ↓              ↓            ↓
   All services    Connect to       Understand     Automated    Complete
   per app        shared Redis     component      component    development
                                   patterns       deployment   environments
```

### The Building Blocks Journey

**Level 100**: See all the pieces - understand what you're abstracting
**Level 150**: Use shared pieces - consume pre-built components
**Level 200**: Understand the patterns - how components are designed
**Level 250**: Automate deployment - GitOps orchestration
**Level 300**: Complete environments - everything working together

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
