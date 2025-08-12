# Software Stacks

*Building complete development environments that eliminate service coordination chaos*

## The Multi-Service Reality

In the previous tutorial, you successfully deployed individual applications. But here's what happens when you try to deploy a complete application stack in Kubernetes.

You've written a web application and want to deploy it to your local Kubernetes cluster. Simple enough, right? But your application needs more than just itself to function properly:

- **A place to store Docker images** - you can't keep pushing to Docker Hub for every development change
- **HTTPS certificates** - your application should use proper TLS, even locally
- **Basic monitoring** - you need to know if your application is healthy
- **Your custom application** - the actual code you wrote

So you start setting up these foundational components one by one.

### Experiencing the Coordination Wall

Let's see this coordination challenge in action. You have a cluster running, and you want to add a private container registry for your custom applications.

```bash
make start
```

The registry component seems straightforward enough. Let's try deploying it:

```bash
kubectl apply -f software/components/registry/
```

**You'll see a mix of success and failure** - some resources create fine (namespace, storage, services) while others fail with errors about missing Certificate resources and namespace dependency issues. The registry component assumes cert-manager is already installed and expects things to be deployed in a specific order.

This is the coordination problem in miniature - the component assumes other services are already there and configured correctly.

Now imagine this same experience multiplied across 10-15 foundation services, each with their own assumptions about what should already be running. You'd spend more time figuring out deployment order and debugging cryptic errors than actually building applications.

### The Natural Response: DIY Orchestration

When teams hit this coordination wall, they naturally start creating their own orchestration. You've probably seen this before:

**The "Magic README" approach** - a step-by-step document that says "First install cert-manager, wait 2 minutes, then run these three kubectl commands, then check if the pods are ready before proceeding..."

**The "Setup Script" approach** - a bash script that tries to sequence everything with sleep commands and basic error checking, hoping the timing works out.

**The "Makefile Dependencies" approach** - using Make targets with dependencies to try to enforce order, but still relying on manual timing and hoping services are actually ready.

These DIY solutions work... sometimes. But they create a bigger architectural problem: **tight coupling**. Your setup script becomes a monolithic sequence that's bound to your specific environment. Want to work on just the monitoring component? You can't - you have to run through the entire certificate chain first. Need to reuse the database setup for a different project? Good luck extracting it from the middle of your 200-line script.

This tight coupling makes development painful. If you're working on something that happens toward the end of the sequence, you can't isolate your work. You're forced to deploy and debug the entire dependency chain every time you want to test a change.

This coordination chaos is exactly why individual application deployment worked smoothly in the previous tutorial, but multi-service environments become nightmares to manage manually.

### Enter: Composable Components

Software stacks solve this by flipping the approach. Instead of tightly-coupled orchestration scripts, you get **composable components** - think Lego blocks that snap together cleanly.

That registry component you just tried to deploy? It's actually well-designed - it handles its own storage, networking, and service configuration. It just expects certain foundation pieces to exist first (like certificate management). This is exactly how components should work: self-contained but composable.

**Components vs Applications:**
- **Components** provide shared infrastructure that multiple applications can use - databases, certificate management, monitoring, container registries
- **Applications** are your business logic - the web services, APIs, and custom code you're actually building

Components are the foundation blocks that make your applications possible. Need to work on just one component? Deploy it in isolation. Want to reuse a component in a different environment? Drop it right into a new stack. This modularity eliminates the tight coupling problem while still handling coordination properly.

## The Stack Solution

Software stacks are like Lego instruction booklets - they tell you which components to use and how they snap together. Instead of writing fragile scripts that manage timing and order manually, you declare what components and applications you want, define their dependencies, and let GitOps automation handle all the sequencing, health checking, and retry logic.

Components solve the modularity problem. Stacks solve the coordination problem. Together, they transform multi-service chaos into manageable, reusable development environments.

**Think of the difference like this:**

- **Manual approach** - Like a model airplane kit with custom pieces that only fit together one way. Want to build something else? You need a completely different kit with different pieces.
- **Stack approach** - Like Lego blocks with instruction booklets. The same modular components can build a spaceship, a castle, or a race car - it all depends on which instruction booklet you follow.

With your DIY orchestration script, you're stuck with that specific sequence for that specific setup. With software stacks, you get modular components that can be combined in different ways to build different application stacks.

### How Stacks Eliminate the Chaos

Remember the manual deployment wall you just hit? Here's how a stack would handle the same scenario:

```bash
make up my-stack
```

**What happens automatically:**
```
Step 1: cert-manager (foundation)
   ↓ (waits for healthy)
Step 2: certificates (depends on Step 1)
   ↓ (waits for healthy)
Step 3: certificate authority (depends on Step 2)
   ↓ (waits for healthy)
Step 4: certificate issuer (depends on Step 3)
   ↓ (waits for healthy)
Step 5: container registry (depends on Step 4)
   → Complete working environment
```

**The magic:** You get the exact same result as the manual coordination you were struggling with, but with zero guesswork, zero timing issues, and zero dependency debugging.

### The Two-Layer Architecture

Think about what you actually need for a production application stack. Your web API is just one piece - it also needs somewhere to store data, certificates for HTTPS, a way to track if it's healthy, and probably a dozen other supporting services.

This creates a natural two-layer architecture. **Components** provide the shared infrastructure foundation - the container registry, certificate management, databases, and monitoring that multiple applications can use. **Applications** contain your actual business logic - the web services, APIs, and custom code that make your product unique.

The key insight is sequencing: components must be healthy before applications try to use them. Your web API can't connect to PostgreSQL if PostgreSQL isn't running yet. The stack handles this automatically - no more debugging connection failures because services aren't ready.

## Building Your Development Environment

Let's create the complete development environment you were trying to build manually. You'll see how the stack "instruction booklet" approach eliminates all the coordination chaos you just experienced.

### Your Development Environment Stack

We'll build a stack that provides everything you need for custom application development:

- **Container Registry** - so you can build and store your own Docker images locally
- **Certificate Management** - automated HTTPS certificates for all your services
- **Monitoring** - basic health monitoring for your applications
- **GitOps Foundation** - the automation system that orchestrates everything

This is the foundation that supports the typical development workflow: write code → build image → deploy application → iterate.

### Breaking the Dependency Puzzle

Remember trying to deploy that registry and hitting the certificate wall? That failure actually reveals a complex dependency puzzle. The registry needs certificates, certificates need a certificate authority, the authority needs cert-manager installed, and cert-manager needs specific timing to be ready.

Manually, you're stuck playing detective - figuring out what depends on what, guessing when things are ready, and often hitting circular dependency situations where A needs B but B also needs A.

**The stack approach flips this completely.** Instead of you figuring out the puzzle, the stack definition declares the relationships clearly: "registry depends on certificate issuer, issuer depends on certificate authority, authority depends on cert-manager." GitOps automation becomes the detective, monitoring each component's health and only proceeding when dependencies are actually satisfied.

Same services, same final result, but the coordination intelligence moves from your head into the automation system.

## Building Your Solution

Now let's build a stack that solves the coordination problem you just experienced. We'll create a complete development environment that handles all those dependencies automatically.

```bash
# Create your stack extension directory
mkdir -p software/stack/extension/tutorial-stack
cd software/stack/extension/tutorial-stack
```

**Every stack needs these three files to work:**

**kustomization.yaml** - The table of contents:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - repository.yaml    # Where to find the components
  - stack.yaml         # The step-by-step instructions
```

**repository.yaml** - Where to find the components:
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

**stack.yaml** - The actual assembly instructions that solve your coordination problems:
```yaml
######################
## Tutorial Stack - Complete Development Environment
## Solves the manual coordination chaos with automated dependencies
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
  wait: true  # Don't proceed until this is healthy
---
# Step 2: Foundation services (deploy in parallel after Step 1)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-metrics-server
  namespace: flux-system
spec:
  dependsOn:  # Wait for Step 1 to complete
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
  dependsOn:  # Also waits for Step 1 (can deploy parallel with metrics)
    - name: component-flux-resources
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/certs  # This installs cert-manager
  prune: true
  wait: true
---
# Step 3: Certificate authority (depends on cert-manager from Step 2)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs-ca
  namespace: flux-system
spec:
  dependsOn:  # Wait for cert-manager to be ready
    - name: component-certs
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/certs-ca
  prune: true
  wait: true
---
# Step 4: Certificate issuer (depends on CA from Step 3)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs-issuer
  namespace: flux-system
spec:
  dependsOn:  # Wait for CA to exist
    - name: component-certs-ca
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/certs-issuer
  prune: true
  wait: true
---
# Step 5: Container registry (uses certificates from Step 4)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-registry
  namespace: flux-system
spec:
  dependsOn:  # Wait for certificate issuer to be ready
    - name: component-certs-issuer
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./software/components/registry
  prune: true
  wait: true
```

**How this solves your coordination problems:**

Each `dependsOn` section tells GitOps automation "don't start this step until the listed steps are completely healthy." The `wait: true` means "don't consider this step done until all its resources are running."

This eliminates all the guesswork, timing issues, and circular dependency problems you experienced with manual deployment.

### Experience the Stack Solution

Now let's see the stack eliminate the coordination chaos you experienced earlier:

```bash
# Deploy your complete development environment
make up extension/tutorial-stack

# Watch the automated orchestration
make status
```

**Compare this to your manual experience:** The GitOps foundation deploys first and sets up the automation system. Then cert-manager and monitoring deploy in parallel since they both just need the foundation. The certificate authority waits for cert-manager to be completely ready before starting. The certificate issuer waits for the CA to exist. Finally, the container registry deploys once certificates are available.

**This is exactly the same set of services you were trying to deploy manually.** But instead of guessing deployment order, waiting and hoping things are ready, or debugging circular dependencies, the stack handles all that coordination intelligence for you. No more half-broken environments or connection debugging sessions.

## The Development Workflow Payoff

Now for the payoff - your stack creates a complete development environment that supports the full custom application development workflow. This is why you needed all that coordination in the first place.

### Your Development Environment in Action

The stack you just deployed provides everything needed for end-to-end application development:

- **Private container registry** - Store your custom Docker images locally
- **Automatic HTTPS certificates** - Secure connections without manual certificate management
- **Health monitoring** - Track your applications and infrastructure
- **GitOps orchestration** - Automated deployment and lifecycle management

### Complete Custom Application Workflow

Here's the development cycle your stack enables:

```bash
# Your development environment is already running
# (from make up extension/tutorial-stack)

# Build your custom application into a Docker image
make build src/registry-demo

# Deploy your application (it pulls from your private registry)
make deploy registry-demo

# Check your running application
make status
```

**What just happened:**

1. `make build` compiled your application code into a Docker image and pushed it to your private registry
2. `make deploy` deployed your application, pulling the image from your own registry (not Docker Hub)
3. Your application is now running with proper certificates and monitoring

**The key insight:** Your application configuration points to `localhost:5443/registry-demo:latest` - your own private registry that the stack provided. This is a complete, self-contained development environment with no external dependencies.

This is the workflow that justifies all the coordination complexity. Without the registry, certificates, and monitoring working together, you can't have this streamlined development experience.

## Understanding What Just Happened

You've gone from manual coordination chaos to a working development environment in minutes. Let's understand how the stack automation eliminated all the problems you experienced.

### How GitOps Eliminates Coordination Problems

Remember trying to figure out deployment order manually? Here's how the stack instruction booklet works:

```yaml
# Each component declares its dependencies
dependsOn:
  - name: component-certs        # "Don't start until this is ready"
path: ./software/components/certs-ca  # "Deploy this component"
wait: true                           # "Don't continue until healthy"
```

**GitOps automation (Flux) becomes your deployment assistant:**
- **Monitors everything continuously** - knows when each component is actually ready
- **Respects dependencies automatically** - won't start anything until prerequisites are healthy
- **Handles failures gracefully** - retries failed deployments without breaking the whole process
- **Maintains consistency** - keeps everything running in the desired state

### The Transformation

| **Manual Approach** (what you experienced) | **Stack Approach** (what you just used) |
|-------------------------------------------|------------------------------------------|
| Guess deployment order | Automated dependency resolution |
| Wait and hope things are ready | Continuous health monitoring |
| Debug why things aren't connecting | Dependencies guaranteed before proceeding |
| Different results every time | Identical deployments every time |
| Manual recovery from failures | Automatic retry and healing |
| Become expert in service coordination | Focus on application development |

### Validation and Troubleshooting

Your stack should be running smoothly, but if something isn't working:

**Check overall stack status:**
```bash
# See all components and their health
make status

# Check GitOps automation status
kubectl get kustomizations -n flux-system
```

**If a component is stuck:**
```bash
# Debug specific component (e.g., registry)
kubectl describe kustomization component-registry -n flux-system
```

**Verify the registry is working:**
```bash
# Test registry access
kubectl port-forward -n registry service/registry 5000:5000
curl http://localhost:5000/v2/    # Should return {}

# Check if your custom image was stored
curl http://localhost:5000/v2/_catalog
```

The troubleshooting is much simpler because the stack guarantees that dependencies are met before anything tries to use them.

## What You've Accomplished

You've transformed from manual service coordination chaos to automated orchestration mastery. More importantly, you've experienced the fundamental shift that makes complex development environments manageable.

**The coordination problem you experienced:**
- Manual dependency guessing and timing mysteries
- Tool juggling between kubectl, helm, and make
- Half-broken environments and debugging nightmares
- Time spent on service coordination instead of application development

**The stack solution you built:**
- Complete development environment deployed with `make up extension/tutorial-stack`
- Automatic dependency resolution and health monitoring
- End-to-end custom application workflow (build → registry → deploy)
- Zero coordination overhead - focus on your applications, not infrastructure

**The key insight:** Software stacks transform multi-service environments from coordination nightmares into simple, reliable development platforms. The same pattern works whether you need 5 services or 50.

### Beyond Tutorial Stacks

Your tutorial stack is just the beginning. The same stack pattern supports any development environment:

- **Database-heavy applications** - PostgreSQL, Redis, Elasticsearch with connection management
- **Microservice platforms** - Service mesh, API gateways, monitoring, and tracing
- **Data platforms** - Airflow, Kafka, data lakes with processing pipelines
- **Enterprise environments** - Security, compliance, audit logging, and RBAC systems

The coordination principles are identical - declare what you want, define dependencies, let GitOps automation handle the orchestration.

### Building Production-Ready Stacks

As you build more sophisticated stacks, you'll extend the patterns you learned here:
- **Multi-environment stacks** - dev, staging, prod variants with different configurations
- **External integration** - connecting to cloud services and existing infrastructure
- **Team collaboration** - shared stacks with personal customization overlays
- **Advanced dependencies** - complex service meshes and data pipeline orchestration

But the core pattern remains the same: eliminate manual coordination through declarative orchestration.

👉 **Continue to:** [Shared Components](shared-components.md) - *Learn how applications connect to and consume the foundation services your stacks provide*
