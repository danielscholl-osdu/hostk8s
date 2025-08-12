# Software Stacks

*Understanding how coordinated service deployment eliminates the operational chaos of managing individual applications*

## The Multi-Service Development Challenge

In the previous tutorial, you deployed individual applications successfully. But real development environments need multiple services working together - databases, caches, certificates, monitoring, and applications all coordinating as a system.

Let's see what happens when you try to manage these services individually.

### The Shared Services Coordination Problem

You're building applications that need shared services to function properly:
- **Container registry** (to store and deploy your custom images)
- **Certificate management** (for HTTPS security)
- **Monitoring** (to track application performance)
- **Your applications** (your actual business logic)

The challenge isn't deploying individual applications - it's coordinating the foundation services with your applications.

**Manual Service Management Chaos:**
Without stacks, you have to set up foundation services manually before applications can work:

```bash
# Set up foundation services manually, in correct order
kubectl apply -f certificate-manager-setup/
helm install monitoring prometheus/kube-prometheus-stack
kubectl apply -f container-registry-setup/
# Wait for everything to be ready...
# Debug connectivity issues...
# Then finally deploy your applications
make deploy my-app-1
make deploy my-app-2
```

**Problems:**
- **Foundation services setup required** before any apps work properly
- **No guidance on service dependencies** (certs need CA, registry needs certs)
- **Inconsistent environments** (teammate forgot monitoring? Apps work but no visibility)
- **Manual coordination** between foundation services and your applications
- **Different setup methods** (kubectl, helm, make deploy) for different pieces



### The Manual Approach Reality

Let's see this coordination challenge in action. In HostK8s, you could theoretically deploy shared service components individually:

```bash
# Make sure you have a cluster
make start

# Try to set up foundation services manually (various methods)
kubectl apply -f software/components/certs/
kubectl apply -f software/components/registry/
helm install metrics-server software/components/metrics-server/
# Debug why things aren't working...
# Figure out dependency order...
# Wait for things to be ready...

# Finally deploy applications
make deploy my-app
```

**What you'll discover:**
- Foundation services fail because dependencies aren't ready
- No clear setup order guidance (certs before registry? metrics-server when?)
- Inconsistent state when things go wrong
- Time spent on service coordination instead of application development
- Different team members set up services differently

This manual approach forces you to become an expert in service dependencies and deployment timing - time that should be spent building your applications.

---

## How Software Stacks Solve This

**Software Stacks** eliminate coordination chaos through automated orchestration. Instead of managing individual services manually, you declare the complete environment you want and let GitOps automation handle the coordination.

Think of it like **Lego blocks** and instruction booklets:

- **Individual services** = Lego blocks (useful pieces but limited alone)
- **Software stack** = Instruction booklet (tells you which blocks to use and how to connect them)
- **GitOps automation** = Following the instructions step-by-step automatically
- **Development environment** = The finished model that actually works

Just like Lego sets, HostK8s has different types of pieces that work together:

| Lego World | HostK8s World |
|------------|---------------|
| **Individual blocks** | **Components** (Redis, databases, certificates) |
| **Specialized pieces** | **Applications** (your web services, APIs) |
| **Instruction booklet** | **Software Stack** (defines what to build and in what order) |
| **Following instructions** | **GitOps automation** (Flux builds it for you) |
| **Finished model** | **Complete development environment** |

### Stack Components vs Applications

```
Software Stack (The Instructions)
         ↓
    ┌─────────┐    ┌──────────────┐
    │Components│ + │ Applications │
    └─────────┘    └──────────────┘
   Foundation        Your Code
```

**Components** provide the shared service foundation:
- **Certificates** (HTTPS security)
- **Databases** (PostgreSQL, Redis)
- **Monitoring** (metrics collection)
- **Container Registry** (for your custom images)

**Applications** are your business logic:
- **Web services** (your APIs)
- **User interfaces** (frontend applications)
- **Data processors** (background jobs)

**Software Stack** coordinates both:
- Deploys components first (foundation)
- Then deploys applications (which use the foundation)
- Handles all the timing and dependencies automatically

### The Stack Advantage

**Manual coordination** (what you experienced):
```bash
make deploy certificates  # Hope it works
make deploy database      # Hope dependencies are ready
make deploy app          # Hope everything connects
# Repeat when things fail...
```

**Stack coordination** (what you're about to learn):
```bash
make up my-stack         # Everything deploys in correct order automatically
```

Same result, zero coordination effort.

---

## Building Your First Stack

Let's build a complete development environment using a software stack. You'll see how the "instruction booklet" approach eliminates the coordination chaos you experienced earlier.

### The Tutorial Stack

We'll build a stack that includes:
- **Container Registry** (for your custom images)
- **Certificate Management** (HTTPS security)
- **Monitoring** (cluster metrics)
- **GitOps Automation** (Flux coordination)

This creates a foundation for building and deploying custom applications - the typical needs of a development environment.

### Stack Dependencies Made Simple

Remember the manual deployment chaos? Here's how the stack handles dependencies automatically:

```
Step 1: GitOps foundation (enables automation)
Step 2: Certificates + Monitoring (foundation services)
Step 3: Certificate Authority (builds on certificates)
Step 4: Certificate Issuer (builds on CA)
Step 5: Container Registry (uses certificates for security)
```

The stack "instruction booklet" ensures each step waits for its dependencies. No more guessing the deployment order or debugging timing issues.

### Creating the Stack Definition

A software stack is defined by three simple files that tell HostK8s what to build. Let's create them:

```bash
# Create your stack extension directory
mkdir -p software/stack/extension/tutorial-stack
cd software/stack/extension/tutorial-stack
```

**Create these three files:**

**kustomization.yaml** - Table of contents:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - repository.yaml
  - stack.yaml
```

**repository.yaml** - Where to find components:
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

**stack.yaml** - The step-by-step instructions (create the complete file):
```yaml
######################
## Tutorial Stack - Complete Development Environment
######################
---
# Step 1: GitOps foundation (enables all automation)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-flux-resources
  namespace: flux-system
spec:
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/flux-resources
  prune: true
  wait: true
---
# Step 2: Foundation services (monitoring and certificates)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-metrics-server
  namespace: flux-system
spec:
  dependsOn:
    - name: component-flux-resources
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/metrics-server
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs
  namespace: flux-system
spec:
  dependsOn:
    - name: component-flux-resources
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/certs
  prune: true
  wait: true
---
# Step 3: Certificate authority (builds on certificates)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs-ca
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/certs-ca
  prune: true
  wait: true
---
# Step 4: Certificate issuer (builds on CA)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs-issuer
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs-ca
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/certs-issuer
  prune: true
  wait: true
---
# Step 5: Container registry (uses certificates)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-registry
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs-issuer
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/registry
  prune: true
  wait: true
```

**What these files do:**
- **kustomization.yaml** tells HostK8s what files to read
- **repository.yaml** points to where HostK8s components are stored
- **stack.yaml** defines the deployment steps and dependencies

### Deploy Your Stack

Now let's see the stack in action and compare it to the manual chaos you experienced:

```bash
# Deploy your complete development environment
make up extension/tutorial-stack

# Watch the automated deployment
make status
```

**What happens automatically:**
1. **GitOps foundation** deploys first
2. **Certificates and monitoring** deploy in parallel (both depend on step 1)
3. **Certificate authority** deploys (waits for certificates)
4. **Certificate issuer** deploys (waits for CA)
5. **Container registry** deploys last (waits for issuer)

Same services as the manual approach, but zero coordination effort. The stack "instruction booklet" handles all the timing and dependencies.

---

## Custom Application Development

Your stack creates a complete development environment. Let's use it to build and deploy a custom application - the typical development workflow.

### The Development Scenario

The stack provides a private container registry. This enables the full development cycle:
1. **Build** your application into a Docker image
2. **Push** to your private registry
3. **Deploy** from your registry to the cluster

### Complete Development Workflow

```bash
# Your development environment is already running
# make up extension/tutorial-stack (from previous step)

# Build a custom application
make build src/registry-demo

# Deploy the application (pulls from your private registry)
make deploy registry-demo

# Access your running application
make status
```

**Key insight:** Your custom application pulls from `localhost:5443/registry-demo:latest` - your own private registry that the stack provided. No external dependencies or Docker Hub requirements.

## Understanding GitOps Coordination

Now that you've seen the stack in action, let's understand how GitOps automation eliminates the coordination chaos.

### How the "Instruction Booklet" Works

Each step in your stack.yaml is a GitOps instruction:

```yaml
# Wait for certificates to be ready
dependsOn:
  - name: component-certs
# Then deploy certificate authority
path: ./software/components/certs-ca
# Don't continue until it's healthy
wait: true
```

**GitOps automation** (Flux) reads these instructions and:
- Monitors component health continuously
- Only proceeds when dependencies are satisfied
- Retries failed deployments automatically
- Maintains desired state over time

### Stack vs Manual Comparison

| Approach | Coordination | Environment Consistency | Failure Recovery |
|----------|-------------|-------------------------|------------------|
| **Manual** | You manage timing | Different every time | Manual debugging |
| **Stack** | Automated dependencies | Identical deployments | Automatic retries |

### Troubleshooting Your Stack

**If components aren't deploying:**
```bash
# Check GitOps status
kubectl get kustomizations -n flux-system

# Debug specific component
kubectl describe kustomization component-registry -n flux-system
```

**If custom app won't deploy:**
```bash
# Verify registry is accessible
kubectl port-forward -n registry service/registry 5000:5000
curl http://localhost:5000/v2/

# Check if image was pushed
curl http://localhost:5000/v2/_catalog
```

---

## What Comes Next

You've experienced the power of software stack coordination - how GitOps automation eliminates the operational chaos of managing individual services. The same `make up` command works regardless of stack complexity, giving you consistent environments for any development scenario.

These software stacks create the foundation for component-based development. In the next tutorial, you'll:
- Connect applications to shared service components
- Learn consumption patterns for databases, caches, and services
- Understand when to build new components vs. use existing ones

The coordinated deployment patterns you've learned here will support the shared component architectures you'll explore next.

👉 **Continue to:** [Using Components](shared-components.md)
