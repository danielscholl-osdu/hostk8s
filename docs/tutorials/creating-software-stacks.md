# Creating Software Stacks

*Learn to compose existing HostK8s components into custom development environments*

**Time Required:** ~60 minutes

## Overview

Think of HostK8s components like **Lego blocks** - each one does something useful (registry, database, certificates), but by themselves they're just individual pieces. A **software stack** is like the instruction booklet that tells you which blocks to use and how to snap them together to build something amazing - a complex microservice platform.

In this tutorial, you'll create a custom **software stack** that combines existing components into a development environment supporting the complete custom application workflow: build → push → deploy.

**What You'll Build:**
- Custom software stack using existing HostK8s components
- Complete registry-based development workflow
- Custom application deployment through your stack

**Prerequisites:**
- Basic Kubernetes knowledge
- Understanding of Docker containers
- Familiarity with HostK8s basics (see [README](../../README.md))



### Tutorial Workflow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   1. Deploy     │    │   2. Build      │    │   3. Deploy     │
│  Tutorial Stack │───▶│  Custom Image   │───▶│  Custom App     │
│                 │    │                 │    │                 │
│  Components +   │    │ src/registry-   │    │ Pulls from      │
│  Registry       │    │ demo → Registry │    │ Registry        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
   GitOps deploys           Docker builds            App runs using
   infrastructure           & pushes to             custom image
                           local registry
```

---

## Part 1: Understanding Software Stacks

### The Lego Block Concept

Just like Lego blocks, HostK8s has:

| Lego World | HostK8s World |
|------------|---------------|
| **Foundation blocks** | **Components** (cert-manager, Istio, PostgreSQL, Redis) |
| **Feature blocks** | **Applications** (web services, APIs, microservices) |
| **Instruction booklet** | **Software Stack** (tells you which blocks to use and how to connect them) |
| **Finished model** | **Running development environment** |
| **Following instructions** | **GitOps/Flux** (automatically assembles everything) |

### Three Types of "Blocks"

```
Software Stack (The Instructions)
  ↙️        ↘️
Components     Applications
(Infrastructure/Middleware)  (Business Logic/Services)
```

**Components** - Infrastructure and middleware "blocks" (installed via Helm charts):
- **Foundational**: cert-manager, Istio, metrics-server
- **Data Layer**: PostgreSQL, Redis, Elasticsearch
- **Platform Services**: Airflow, observability, service mesh
- **Security**: Certificate management, RBAC systems

**Applications** - Business logic and service "blocks" (installed via Helm charts):
- **Microservices**: API services, web services, data processors
- **Service Groups**: Related microservices that form a complete platform layer
- **User-Facing Services**: Web UIs, mobile backends, customer APIs

**Software Stack** - The "instruction booklet" that defines:
- Which components and applications to deploy
- Dependency order (components typically before applications)
- How they connect and communicate
- Configuration and environment settings

### Why Stacks Matter

Without a stack, you have:
- ❌ Loose components that don't work together
- ❌ Manual setup every time
- ❌ Inconsistent environments
- ❌ Deployment chaos

With a stack, you get:
- ✅ Components that snap together perfectly
- ✅ One command deployment (`make up my-stack`)
- ✅ Consistent, reproducible environments
- ✅ GitOps automation

---

## Part 2: Your Lego Block Collection

Let's examine the existing HostK8s components (your "block collection") we'll use to build our tutorial stack.

### Available Components

**Platform Add-ons** (Kubernetes platform extensions):
- **flux-resources**: GitOps automation system - like the Lego building table that enables construction

**Components** (Infrastructure "blocks" installed via Helm):

| Component | Type | Purpose | Like a Lego... |
|-----------|------|---------|----------------|
| **metrics-server** | Platform Service | Cluster monitoring | Sensor block - tells you what's happening |
| **certs** | Security | Certificate management (cert-manager) | Safety block - keeps things secure |
| **certs-ca** | Security | Root certificate authority | Master key block |
| **certs-issuer** | Security | Certificate issuer | Key maker block |
| **registry** | Platform Service | Docker image storage | Storage block - holds your custom pieces |

**Complex Components** (from complex HostK8s stacks):
- **platform-system**: Istio service mesh, Redis cluster, PostgreSQL operator, Elastic operator
- **elastic-search**: Elasticsearch cluster for search and analytics
- **airflow**: Workflow orchestration and data pipeline management
- **observability**: Prometheus, Grafana, Jaeger for monitoring and tracing

### Component Dependencies

Just like Lego instructions show "Step 1, then Step 2", components have dependencies:

```
Step 0: flux-resources (platform add-on - enables GitOps automation)
Step 1: metrics-server, certs (foundation components)
Step 2: certs-ca (builds on certs)
Step 3: certs-issuer (builds on certs-ca)
Step 4: registry (builds on certs-issuer)
```

**Why This Order Matters:**
- flux-resources is the platform add-on that enables GitOps - like having a proper building table
- certs must be installed before you can create certificates
- certs-ca must exist before certs-issuer can issue certificates
- registry needs certificates to run securely

### Understanding Stack Complexity

Complex stacks can have multiple layers with many interdependent components:

```
Complex Stack Example:
┌─────────────────────────────────────────────────────────────┐
│ Applications (Business Logic)                               │
│ • Capability Group 1: service-1, service-2 (auth)         │
│ • Capability Group 2: service-3, service-4 (user mgmt)    │
│ • Capability Group 3: service-5, service-6 (data proc)    │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Components (Installed by Flux)                            │
│ • Security: cert-manager, certificate authorities         │
│ • Networking: Istio service mesh, ingress controllers     │
│ • Databases: PostgreSQL, Elasticsearch                    │
│ • Cache & Messaging: Redis cluster, message queues        │
│ • Platform Services: Airflow, observability, monitoring   │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│ Foundation (Pre-installed)                                │
│ • Kubernetes: etcd, DNS, API server, scheduler            │
│ • Storage: Persistent volumes, storage classes            │
│ • Container Runtime: containerd, kubelet                  │
│ • Add-ons: Flux (kubectl apply), metrics-server (kubectl) │
└─────────────────────────────────────────────────────────────┘
```

Our tutorial stack is intentionally simple, focusing on the registry development workflow.

### The Registry Component Deep Dive

Since our stack will include a registry for custom images, let's examine this "block":

The registry component includes:
- **Namespace**: Isolates the registry in its own space
- **PV/PVC**: Persistent storage (data survives restarts)
- **Deployment**: The actual Docker registry container
- **Service**: Network access (internal + external)

**What It Does:**
- Stores custom Docker images you build
- Provides HTTP API for push/pull operations
- Persists images in host storage (`data/registry/`)
- See Quick Reference section for endpoints and ports

---

## Part 3: Creating Your Tutorial Stack

### Step 1: Create Local Stack Files

First, create your tutorial stack locally as a HostK8s extension. This follows the standard HostK8s extension pattern and makes it easy to test and iterate.

**Create the extension directory:**
```bash
mkdir -p software/stack/extension/tutorial-stack
cd software/stack/extension/tutorial-stack
```

### Step 2: Define Your Stack

Every software stack needs three files in the extension directory:

#### kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - repository.yaml
  - stack.yaml
```

#### repository.yaml
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 5m
  url: https://community.opengroup.org/danielscholl/hostk8s
  ref:
    branch: main
  ignore: |
    # exclude all
    /*
    # include only shared components
    !/software/components/
```

#### stack.yaml (first part)
```yaml
######################
## Tutorial Stack
## Development stack for tutorial: includes registry, certs, and monitoring
######################
---
# Flux foundation - always required first
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-flux-resources
  namespace: flux-system
spec:
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/flux-resources
  prune: true
  wait: true
  healthChecks:
    - kind: Deployment
      name: helm-controller
      namespace: flux-system
    - kind: Deployment
      name: kustomize-controller
      namespace: flux-system
    - kind: Deployment
      name: source-controller
      namespace: flux-system
```

*(The stack.yaml file continues with metrics-server, certs, certs-ca, certs-issuer, and registry - see the full file in your tutorial-stack directory)*

### Understanding the Files

Now that you've seen the complete structure, let's understand what each file does:

**kustomization.yaml** - Table of contents
- Tells Kustomize: "Read the repository configuration, then follow the stack assembly instructions"

**repository.yaml** - Where to find the HostK8s components
- **url**: Points to the main HostK8s repo to get the shared components
- **branch**: Which version to use (`main` for latest)
- **ignore**: Only sync the shared components directory (efficiency)
- **Note**: This references the HostK8s components, while your stack lives in your separate repo

**stack.yaml** - Assembly instructions
- Defines the dependency sequence (see Part 2 for details)
- **dependsOn**: "Don't start this block until these blocks are ready"
- **healthChecks**: "This block is ready when these specific things are running"
- **wait: true**: "Don't continue to next block until this one is healthy"

### Step 3: Initialize as Git Repository

Once you've created your stack files, initialize the extension as a Git repository to make it shareable and version-controlled:

```bash
# From the tutorial-stack directory
git init
git add .
git commit -m "Initial tutorial stack configuration"

# Create a new repository on GitHub/GitLab named 'tutorial-stack'
# Then push your local repository:
git remote add origin https://github.com/your-username/tutorial-stack.git
git push -u origin main
```

**Why This Step Matters:**
- Version control for your stack configuration
- Easy sharing with team members
- Backup of your custom stack design
- Foundation for collaborative development

### Understanding the Instructions

Each component definition is like a step in your Lego instructions:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-registry          # Step name
spec:
  dependsOn:                        # Wait for these steps first
    - name: component-certs-issuer
  path: ./software/components/registry  # Which block to use
  healthChecks:                     # How to know it's working
    - kind: Deployment
      name: registry
      namespace: registry
```

This tells Flux: "Deploy the registry component, but only after certs-issuer is ready, and don't consider it done until the registry deployment is healthy."

---

## Part 4: Custom Application Workflow

Now that we understand our stack, let's use it for a complete custom application workflow.

### The Development Scenario

You've built a custom web application and want to:
1. **Build** it into a Docker image
2. **Push** it to your private registry (in the stack)
3. **Deploy** it to run in your development environment

### Your Custom Application

HostK8s includes a sample application called `registry-demo` specifically for this workflow:

This is a simple web application that demonstrates the registry workflow. It's designed to show build metadata and registry integration.

### The Workflow Commands

Once your tutorial stack is running, the workflow is:

```bash
# 1. Deploy your tutorial stack (local extension)
make up extension/tutorial-stack

# 2. Build your custom application
make build src/registry-demo

# 3. Deploy your application (pulls from your registry)
make deploy registry-demo
```

Let's understand what each step does:

#### Step 1: Deploy Tutorial Stack
`make up extension/tutorial-stack` tells HostK8s:
- Use the local extension stack in `software/stack/extension/tutorial-stack/`
- Read the tutorial-stack instructions from your extension directory
- Deploy components in dependency order
- Wait for each component to be healthy
- Result: Complete development environment with private registry

#### Step 2: Build Custom Application
`make build src/registry-demo` tells HostK8s:
- Find the application source code
- Build it into a Docker image
- Tag it with your registry address
- Push it to your private registry
- Result: Custom image available for deployment

#### Step 3: Deploy Application
`make deploy registry-demo` tells HostK8s:
- Find the application deployment configuration
- Pull the image from your private registry
- Deploy it to your cluster
- Result: Custom application running and accessible

### Application Deployment Configuration

Your custom application also needs an "instruction" for how to deploy. The key part is:

```yaml
containers:
- name: registry-demo
  image: localhost:5443/registry-demo:latest  # Pulls from your private registry
```

This tells Kubernetes: "Pull this container image from localhost:5443 (your private registry) instead of Docker Hub."

---

## Part 5: Testing Your Stack

Let's deploy and test your custom tutorial stack.

### Deployment

```bash
# Deploy your custom tutorial stack (local extension)
make up extension/tutorial-stack
```

**What happens:**
1. HostK8s reads your stack "instructions"
2. Flux deploys components in dependency order
3. Each component waits for its dependencies to be healthy
4. Result: Complete development environment with registry

### Monitor Progress

```bash
# Watch the deployment happen
make status
```

You'll see components deploy in order:
- ✅ flux-resources (first)
- ✅ metrics-server, certs (parallel)
- ✅ certs-ca (after certs)
- ✅ certs-issuer (after certs-ca)
- ✅ registry (after certs-issuer)

---

## Part 6: Testing Your Stack

Now let's test the complete development workflow your tutorial stack enables.

### Test Registry Access

First, verify your private registry is working:

```bash
# Test registry API (may need port-forward if NodePort not accessible)
kubectl port-forward -n registry service/registry 5000:5000 &
curl http://localhost:5000/v2/

# Should return: {}
```

### Build Custom Application

The tutorial stack enables the full build → push → deploy workflow:

```bash
# Build your custom application and push to private registry
make build src/registry-demo
```

**What happens:**
- HostK8s finds the `src/registry-demo` application source
- Builds Docker image from the source code
- Tags image for your private registry (`localhost:5045/registry-demo:latest`)
- Pushes to your tutorial stack's registry
- Image is now available for deployment

### Deploy Custom Application

```bash
# Deploy the application (pulls from your private registry)
make deploy registry-demo

# Check deployment status
kubectl get pods -l app=registry-demo
```

**What happens:**
- HostK8s reads the `registry-demo` deployment configuration
- Kubernetes pulls the image from your private registry
- Application starts using your custom-built image
- Result: Your code running in your development environment

### Access Your Application

```bash
# Check if application is accessible
kubectl port-forward service/registry-demo 8080:80 &
curl http://localhost:8080

# Or check pod logs
kubectl logs -l app=registry-demo
```

### Validation Checklist

Your tutorial stack is working when:

✅ **Registry API responds**: `curl http://localhost:30500/v2/` returns `{}`
✅ **Custom image builds**: `make build src/registry-demo` succeeds
✅ **Image in registry**: `curl http://localhost:30500/v2/_catalog` shows `{"repositories":["registry-demo"]}`
✅ **App deploys**: `kubectl get pods -l app=registry-demo` shows running pods
✅ **App accessible**: `curl http://localhost:30510` returns HTML

### Troubleshooting

**Component stuck deploying?**
```bash
kubectl describe kustomization component-name -n flux-system
```

**Registry not accessible?**
```bash
kubectl get pods -n registry
kubectl logs -n registry deployment/registry
```

**Application won't start?**
```bash
kubectl describe pods -l app=registry-demo
kubectl logs -l app=registry-demo
```

---

## Advanced Patterns

### Mixed Installation Patterns

While this tutorial focuses on GitOps-managed stacks, HostK8s stacks also serve as excellent foundations for manually installed applications:

```
┌─────────────────────────────────────────┐
│ Manual Applications (helm/kubectl)     │  ← Added manually
│ • dev-tools, monitoring dashboards     │
│ • experimental apps, personal tools    │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Stack Applications (GitOps-managed)    │  ← From stack.yaml
│ • Capability groups and microservices  │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ Stack Components (GitOps-managed)      │  ← Shared foundation
│ • Databases, networking, monitoring    │
└─────────────────────────────────────────┘
```

**Example Workflow:**
```bash
# Deploy your stack foundation (local extension)
make up extension/tutorial-stack

# Stack provides PostgreSQL, Redis, service mesh, monitoring...

# Then manually add development tools
helm install pgadmin postgresql/pgadmin4
kubectl apply -f my-debug-pod.yaml
```

This approach leverages stack-provided infrastructure while maintaining development flexibility. The manually installed applications can use the databases, networking, and monitoring that your stack provides.

---

---

## Part 7: Summary and Next Steps

### What You Accomplished

Congratulations! You've successfully created your first custom HostK8s software stack and tested the complete development workflow:

**🎯 Core Concepts Mastered:**
- ✅ **Lego Block Analogy** - Components as building blocks, stacks as instructions
- ✅ **Component Dependencies** - Understanding build order and health checks
- ✅ **GitOps Automation** - How Flux orchestrates deployments
- ✅ **Extension Pattern** - Creating reusable, shareable stacks

**🛠️ Technical Skills Gained:**
- ✅ **Stack Creation** - Built complete `tutorial-stack` with 5 components
- ✅ **Git Integration** - Version-controlled your stack design
- ✅ **Local Extension Workflow** - `make up extension/tutorial-stack`
- ✅ **Custom Application Pipeline** - Build → Push → Deploy cycle
- ✅ **Infrastructure Validation** - Verified all components working together

**🏗️ Infrastructure You Built:**
- **Private Docker Registry** - For storing your custom images
- **Certificate Management** - Automated TLS certificates via cert-manager
- **Cluster Monitoring** - Metrics collection with metrics-server
- **GitOps Foundation** - Flux controllers for automated deployments
- **Complete Development Environment** - Ready for real application development

### Your Development Workflow

You now have a complete development environment that supports:

```bash
# 1. Deploy your development infrastructure
make up extension/tutorial-stack

# 2. Build your application
make build src/my-app

# 3. Deploy your application
make deploy my-app

# 4. Iterate and develop
# (make changes, rebuild, redeploy)
```

### Next Steps

**Immediate:**
1. **Experiment** - Try modifying component versions or adding new components
2. **Build Real Apps** - Use this stack for actual application development
3. **Share Your Stack** - Team members can clone and use your tutorial-stack

**Advanced:**
1. **Create Specialized Stacks** - Build web-stack, api-stack, or data-stack variants
2. **Add Complex Components** - Include databases, message queues, or monitoring
3. **Production Considerations** - Add backup, security, and scaling configurations
4. **Multi-Environment** - Create dev/staging/prod variants of your stack

### Key Principles Learned

- **Composability** - Small, focused components combine into powerful systems
- **Dependency Management** - Proper ordering ensures reliable deployments
- **GitOps Workflow** - Infrastructure as code with automatic reconciliation
- **Extension Pattern** - Local development with easy sharing and collaboration
- **End-to-End Pipeline** - From source code to running application

### Troubleshooting Quick Reference

**Stack won't deploy?**
```bash
make status
kubectl get kustomizations -n flux-system
kubectl describe kustomization <failing-component> -n flux-system
```

**Registry not accessible?**
```bash
kubectl port-forward -n registry service/registry 5000:5000
curl http://localhost:5000/v2/
```

**Application won't start?**
```bash
kubectl get pods -l app=<app-name>
kubectl logs -l app=<app-name>
kubectl describe pods -l app=<app-name>
```

### Additional Resources

- [HostK8s Architecture Guide](../architecture.md) - Deep dive into HostK8s design
- [Available Components](../../software/components/) - All built-in components
- [Example Stacks](../../software/stack/) - More stack examples
- [Extension Patterns](../adr/004-extension-system-architecture.md) - Advanced extension techniques

---

**🎉 Congratulations!** You've mastered HostK8s software stack creation. You now have the foundation to build any development environment you need, from simple applications to complex distributed systems. The same patterns and principles apply whether you're building a personal project or enterprise infrastructure.
