# Software Stacks

*Building complete development environments that eliminate service coordination chaos*

## The Multi-Service Reality

In the previous tutorial, you successfully deployed individual applications. But here's what happens when you try to deploy a complete application stack in Kubernetes.

You've written a web application and want to deploy it to your local Kubernetes cluster. Simple enough, right? But your application needs more than just itself to function properly.

You need a place to store Docker images because you can't keep pushing to Docker Hub for every development change. HTTPS certificates are essential since your application should use proper TLS, even locally. Basic monitoring lets you know if your application is healthy. And of course, you need to deploy your actual custom application code.

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

**You'll see a mixture of results** because some resources create fine (namespace, storage, services) while others fail with errors about missing certificate resources and namespace dependency issues. The registry component assumes cert-manager is already installed and expects things to be deployed in a specific order.

This is a typical coordination problem. The component assumes other services are already there and configured correctly.

Now imagine this same experience multiplied across 5-10 foundational components, each with their own assumptions about what should already be running. You'd spend more time figuring out deployment order and debugging cryptic errors than actually building applications.

### The Natural Response: DIY Orchestration

When projects hit this coordination wall, they naturally start creating their own orchestration. You've probably seen this before: **'Magic README' files** with step-by-step procedures that say "run this command, verify the output shows 'Ready', then copy-paste the next block and wait for completion," or **bash scripts** with sleep commands, excessive or not enough logging and crossed fingers hoping services are actually ready before continuation.


These DIY solutions work sometimes, but create a bigger architectural problem: **tight coupling**. Your setup script becomes a monolithic sequence bound to your specific environment. Want to work on just the monitoring component? You can't because you have to run through the entire process first. This tight coupling makes development painful because you can't isolate your work.

This coordination chaos is exactly why individual application deployment worked smoothly in the previous tutorial, but multi-service environments become nightmares to manage manually.

### Enter: Composable Components

Software stacks solve this by flipping the approach. Instead of tightly-coupled orchestration scripts, you get **composable components** that work like Lego blocks snapping together cleanly.

That registry component you just tried to deploy? It's actually well-designed because it handles its own storage, networking, and service configuration. It just expects certain foundation pieces to exist first. This is exactly how components should work: self-contained but composable.

**Components vs Applications:**

Components provide shared capabilities that multiple applications can use. Think databases, certificate management, monitoring, and container registries. Applications contain your business logic: the web services, APIs, and custom code you're actually building.

Components are the foundation blocks that make your applications possible. Need to work on just one component? Deploy it in isolation. Want to reuse a component in a different environment? Drop it right into a new stack. This modularity eliminates the tight coupling problem while still handling coordination properly.

## The Stack Solution

Software stacks are like Lego instruction booklets that tell you which components to use and how they snap together. Instead of writing fragile scripts that manage timing and order manually, you declare what components and applications you want, define their dependencies, and let an automated orchestration framework handle all the sequencing, health checking, and retry logic.

This automated orchestration is called **GitOps** - it continuously monitors your desired state configuration and automatically works to make reality match it. You declare what you want; GitOps figures out how to get there and keep it there.

Components solve the modularity problem. Stacks solve the coordination problem. Together, they transform multi-service chaos into manageable, reusable development environments.

**Think of the difference like this:**

The manual approach is like a model airplane kit with custom pieces that only fit together one way. Want to build something else? You need a completely different kit with different pieces.

The stack approach is like Lego blocks with instruction booklets. The same modular components can build a spaceship, a castle, or a race car, it all depends on which instruction booklet you follow.

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

Think about what you actually need for a complete application stack. Your web API is just one piece, but it also needs somewhere to store data, certificates for HTTPS, a way to track if it's healthy, and probably a dozen other supporting services.

This creates a natural two-layer architecture. **Components** provide the shared foundation: the container registry, certificate management, databases, and monitoring that multiple applications can use. **Applications** contain your actual business logic: the web services, APIs, and custom code that make your product unique.

The key insight is managing dependencies: components must be healthy before applications try to use them. Instead of guessing the order, each component declares what it depends on, and the stack handles this automatically, so no more debugging connection failures because services aren't ready.

## Building Your Development Environment

Let's create the complete software solution you were trying to deploy manually. You'll see how the stack "instruction booklet" approach eliminates all the coordination chaos you just experienced.

### Your Development Environment Stack

We'll build a stack with four essential components. A container registry stores your Docker images locally instead of pushing every change to Docker Hub. Certificate management provides HTTPS even in development, which many modern frameworks now require. Basic monitoring lets you know when things break. The GitOps foundation acts as the automation engine that orchestrates everything.

Together, these components create a platform supporting the complete build, store, deploy, and monitor cycle that real development workflows need.

## Building Your Solution

Now let's build a stack that solves the coordination problem you just experienced. We'll create the same development environment you tried to build manually, but this time with proper orchestration that handles all the dependencies automatically.

The stack will use **Flux** to implement GitOps automation. Flux acts as the orchestration engine that watches your desired state and continuously works to make reality match it. You declare what you want; GitOps figures out how to get there and keep it there.

```bash
# Create your stack extension directory
mkdir -p software/stack/extension/tutorial-stack
cd software/stack/extension/tutorial-stack
```

To understand how stacks work, let's look at the three files that make them possible.

First, `kustomization.yaml` acts as the table of contents:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - repository.yaml    # Where to find the components
  - stack.yaml         # The step-by-step instructions
```

Second, `repository.yaml` tells GitOps where to find components:
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

Finally, `stack.yaml` defines how components depend on each other:
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs
  namespace: flux-system
spec:
  path: ./software/components/certs
  wait: true  # Must be healthy before continuing
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-registry
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs  # Wait for certs first
  path: ./software/components/registry
  wait: true
```

**The Stack Recipe**

The `stack.yaml` file is where the orchestration magic happens. Each component gets its own section that declares two critical things: where to find the component (`path: ./software/components/registry`) and what it depends on (`dependsOn: component-certs-issuer`).

The beauty is in the dependency declarations. GitOps reads these and creates an execution plan: start with components that have no dependencies, wait for them to be healthy, then start the next tier. The registry waits for certificate issuer, which waits for certificate authority, which waits for basic certificates, which waits for cert-manager installation.

This declarative approach eliminates all the timing guesswork you experienced manually. Each component simply declares "I need these other components to be healthy first" and GitOps figures out the rest.

Here's what a simple stack.yaml looks like with just two components:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs
  namespace: flux-system
spec:
  path: ./software/components/certs
  wait: true  # Must be healthy before continuing
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-registry
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs  # Wait for certs first
  path: ./software/components/registry
  wait: true
```

The complete tutorial-stack follows this same pattern with a full dependency chain:
```yaml
# The complete tutorial-stack.yaml dependency flow:
# component-flux-resources     (no dependencies - starts first)
# component-metrics-server     (depends on flux-resources)
# component-certs             (depends on flux-resources)
# component-certs-ca          (depends on certs)
# component-certs-issuer      (depends on certs-ca)
# component-registry          (depends on certs-issuer - deploys last)
```

This creates the exact dependency sequence that eliminates the coordination chaos you experienced manually.

### Experience the Stack Solution

Now let's see the stack eliminate the coordination chaos you experienced earlier:

```bash
# Deploy your complete development environment (takes 2-3 minutes)
make up extension/tutorial-stack

# Watch the automated orchestration happen
make status
```

You'll see the GitOps automation orchestrating everything:
```
[12:27:33] Cluster Addons
🔄 Flux (GitOps): Ready
   Status: GitOps automation available (v2.6.4)

[12:27:34] GitOps Resources
[OK] Kustomization: component-certs
   Message: Applied revision: main@sha1:40e82c67

[OK] Kustomization: component-certs-ca
   Message: Applied revision: main@sha1:40e82c67

[OK] Kustomization: component-certs-issuer
   Message: Applied revision: main@sha1:40e82c67

[OK] Kustomization: component-registry
   Message: Applied revision: main@sha1:40e82c67
```

**What you'll see:** The GitOps foundation deploys first and sets up the automation system. Then cert-manager and monitoring deploy in parallel since they both just need the foundation. The certificate authority waits for cert-manager to be completely ready before starting. The certificate issuer waits for the CA to exist. Finally, the container registry deploys once certificates are available.

**This is exactly the same set of services you were trying to deploy manually.** But instead of guessing deployment order, waiting and hoping things are ready, or debugging circular dependencies, the stack handles all that coordination intelligence for you. No more half-broken environments or connection debugging sessions.

## Why This Coordination Matters

Now for the payoff - your stack creates a complete development environment that supports the full custom application development workflow. This is why you needed all that coordination in the first place.

### Your Complete Development Platform

The stack you just deployed gives you everything needed for end-to-end application development. You now have a private container registry to store your custom Docker images locally, automatic HTTPS certificates without manual certificate management, health monitoring to track your applications and infrastructure, and GitOps orchestration managing the entire lifecycle automatically.

### The Complete Development Cycle

Here's the development workflow your stack enables:

```bash
# Build your custom application and push to your private registry
make build src/registry-demo

# Deploy your application (it pulls from your own registry)
make deploy registry-demo

# See your complete development environment in action
make status
```

Your complete development platform is now running:
```
[12:27:36] GitOps Applications
📦 registry.registry
   Deployment: registry (1/1 ready)
   Service: registry (ClusterIP)
   Access: https://localhost:5443 (registry ingress)

📱 registry-demo.default
   Deployment: registry-demo (1/1 ready)
   Service: registry-demo (ClusterIP)
   Access: http://localhost:8080/registry-demo (registry-demo ingress)

[12:27:37] Health Check
All deployed apps are healthy
```

**This is the payoff for all that coordination work.** When you build, your application gets compiled into a Docker image and pushed to your own private registry. When you deploy, your application pulls from that registry (not Docker Hub) and starts running with proper certificates and monitoring already in place.

Your application configuration points to `localhost:5443/registry-demo:latest` - your own infrastructure that the stack coordinated for you. This is a complete, self-contained development environment where everything just works together.

## Understanding What Just Happened

You've gone from manual coordination chaos to a working development environment in minutes. The key insight is where the coordination intelligence lives.

### From Human Detective to Automated Assistant

Remember playing dependency detective manually? The stack flips this completely. Each component declares its dependencies explicitly: "don't start until component-certs is ready," "deploy this specific component," "don't continue until everything is healthy."

The GitOps automation continuously monitors when each component is actually ready, respects dependencies automatically, handles failures gracefully with retries, and maintains consistency by keeping everything running in the desired state.

**The transformation:** coordination intelligence moves from your head into the automation system.

### The Coordination Intelligence Transfer

You've experienced a fundamental shift in where coordination intelligence lives. Before, you were the dependency detective, manually figuring out what needed to happen when. Now, the stack declarations contain that intelligence, and GitOps automation executes it reliably every time.

This intelligence transfer is what makes complex multi-service environments manageable.

### When Things Go Wrong

Troubleshooting is much simpler now because the stack guarantees dependencies are met before anything tries to use them. Most issues are component-specific rather than coordination problems.

**Start with the big picture:** `make status` shows all components and their health, while `kubectl get kustomizations -n flux-system` shows the GitOps automation status.

**Drill down to specifics:** If a component is stuck, `kubectl describe kustomization component-registry -n flux-system` will show exactly what's happening with that component.

**Test the actual services:** For the registry specifically, you can test direct access with port-forwarding and verify your custom images are actually stored there.

The key difference from manual coordination debugging: you're debugging individual component behavior, not trying to figure out why services can't find each other.

## What Just Changed for You

You've experienced the fundamental shift that makes complex development environments manageable. Remember that registry deployment failure at the beginning? That coordination chaos is now completely eliminated.

**Before this tutorial:** You were stuck playing dependency detective, guessing what needed to be deployed first, juggling different tools, debugging half-broken environments, and spending more time on service coordination than actual application development.

**After this tutorial:** You have a complete development environment deployed with one command, automatic dependency resolution and health monitoring handling all the complexity, an end-to-end custom application workflow from build to deployment, and zero coordination overhead so you can focus on your applications instead of infrastructure.

**The transformation:** Software stacks move multi-service environments from coordination nightmares into simple, reliable development platforms. The same pattern scales whether you need 5 services or 50.

### From Tutorial to Production

Your tutorial stack is just the beginning. The same coordination principles apply to any application stack you need to build. Database-heavy applications need PostgreSQL, Redis, and Elasticsearch with proper connection management. Microservice platforms require service meshes, API gateways, monitoring, and distributed tracing. Data platforms coordinate Airflow, Kafka, data lakes, and processing pipelines. Enterprise environments add security layers, compliance tools, audit logging, and RBAC systems.

The pattern remains the same: declare what components you want, define their dependencies, and let GitOps automation handle the orchestration complexity.

### Advanced Stack Patterns

As you build more sophisticated stacks, you'll extend these patterns in predictable ways. Multi-environment stacks create dev, staging, and prod variants with different configurations but the same coordination logic. External integration connects to cloud services and existing infrastructure while maintaining the declarative approach. Team collaboration uses shared stacks with personal customization overlays. Advanced dependencies handle complex service meshes and data pipeline orchestration.

The core insight never changes: eliminate manual coordination through declarative orchestration. The complexity stays in the automation system, not in your head.

👉 **Continue to:** [Shared Components](shared-components.md) - *Learn how applications connect to and consume the foundation services your stacks provide*
