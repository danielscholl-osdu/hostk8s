# Software Stacks

*Building complete development environments that eliminate service coordination chaos*

## The Multi-Service Reality

In the previous tutorial, you successfully deployed individual applications. But here's what happens when you try to deploy a complete application stack in Kubernetes.

You've written a web application and want to deploy it to your local Kubernetes cluster. Simple enough, right? But your application needs more than just itself to function properly.

You need a place to store Docker images because you can't keep pushing to Docker Hub for every development change. HTTPS certificates are essential since your application should use proper TLS, even locally. Basic monitoring lets you know if your application is healthy. And of course, you need to deploy your actual custom application code.

So you start setting up these **foundational components** one by one.

### Experiencing the Coordination Wall

Let's see this coordination challenge in action. You have a cluster running, and you want to add a private container registry for your custom applications.

```bash
make start
```

The registry component seems straightforward enough. Let's try deploying it:

```bash
kubectl apply -f software/components/registry/
```

**You'll see a mixture of results** because some resources create fine while others fail with errors about missing certificate resources and namespace dependency issues. The registry component assumes cert-manager is already installed and expects things to be deployed in a specific order.

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

## How Stacks Eliminate Chaos

Software stacks are like Lego instruction booklets that tell you which components to use and how they snap together. Instead of writing fragile scripts that manage timing and order manually, you declare what components and applications you want, define their dependencies, and let an automated orchestration framework handle all the sequencing, health checking, and retry logic.

**Think of the difference like this:**

The manual approach is like a model airplane kit with custom pieces that only fit together one way. Want to build something else? You need a completely different kit with different pieces.

The stack approach is like Lego blocks with instruction booklets. The same modular components can build a spaceship, a castle, or a race car, it all depends on which instruction booklet you follow.

This automated orchestration is called **GitOps** - it continuously monitors your desired state configuration and automatically works to make reality match it. You declare what you want; GitOps figures out how to get there and keep it there.

Components solve the modularity problem. Stacks solve the coordination problem. Together, they transform multi-service chaos into manageable, reusable development environments.

### Stack Solution in Action

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

## Building Your Software Stack

Let's create a complete software solution. You'll see how the stack "instruction booklet" approach eliminates all the coordination chaos you just experienced.

### Your Software Stack Components

We'll examine a stack with essential components that work together. Certificate management provides HTTPS capabilities that modern web applications require. An ingress controller handles external traffic routing to your applications. Sample applications demonstrate how business logic connects to the foundation components.

Together, these components create a complete web application platform that eliminates the coordination chaos you experienced manually.

## Understanding Stack Structure

Now let's break down a stack that solves the coordination problem you just experienced. The stack will use **Flux** as the tool to implement the GitOps automation. Flux acts as the orchestration engine that watches your desired state and continuously works to make reality match it. You declare what you want; Flux figures out how to get there and keep it there.

To understand how stacks work, lets example the sample stack and look at the three files that make them possible.

First, `kustomization.yaml` acts as the table of contents:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - repository.yaml    # Where to find the components
  - stack.yaml         # The step-by-step instructions
```

The next files are GitOps configurations that the Flux tool uses as part of the GitOps automation process.

Second, `repository.yaml` tells Flux where to find components:
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
  wait: true                                 # Must be healthy before continuing
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-registry
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs                  # Wait for certs before starting
  path: ./software/components/registry
  wait: true                                 # Must be healthy before continuing
```

### The Stack Recipe

The `stack.yaml` file is where the orchestration magic happens. Each component gets its own section that declares two critical things:

| Property | Purpose | Example |
|----------|---------|---------|
| `path` | Where to find the component | `./software/components/registry` |
| `dependsOn` | What it depends on | `component-certs-issuer` |

The beauty is in the dependency declarations - this declarative approach eliminates all the timing guesswork you experienced manually. Each component simply declares "I need these other components to be healthy first" and Flux figures out the rest.

Flux reads these configurations and creates an execution plan: start with components that have no dependencies, wait for them to be healthy, then start the next tier.

The dependency chain flows like this:
`certs` → `certs-ca` → `certs-issuer` → `ingress-nginx` → `[sample applications]`

Here's what a simple `stack.yaml` looks like with two components:

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

First, certificate management deploys and gets the foundation ready. Then, the certificate authority waits for basic certificates. Next, the certificate issuer waits for the CA. Finally, the ingress controller deploys once certificates are available, followed by the sample applications.

This creates the exact dependency sequence that eliminates the coordination chaos you experienced manually.

### Experience the Stack Solution

Now let's see the stack eliminate the coordination chaos you experienced earlier:

```bash
# Deploy your complete software stack (takes 2-3 minutes)
make up sample

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

## Cleaning Up Your Stack

Now that you've seen the stack in action, let's learn how to manage its lifecycle. One of the key benefits of stacks is clean removal:

```bash
# Remove the entire stack cleanly
make down sample
```

Watch as GitOps automation removes components in reverse dependency order, ensuring clean teardown without orphaned resources. This is the same coordination intelligence working in reverse - dependencies are respected during removal just like they were during deployment.

## Understanding What Just Happened

You've gone from manual coordination chaos to automated environment deployment in minutes. The key insight is where the coordination intelligence lives.

### From Human Detective to Automated Assistant

Remember playing dependency detective manually? The stack flips this completely. Each component declares its dependencies explicitly: "don't start until component-certs is ready," "deploy this specific component," "don't continue until everything is healthy."

Flux continuously monitors when each component is actually ready, respects dependencies automatically, handles failures gracefully with retries, and maintains consistency by keeping everything running in the desired state.

**The transformation:** coordination intelligence moves from your head into the automation system.

### When Things Go Wrong

Troubleshooting is much simpler now because the stack guarantees dependencies are met before anything tries to use them. Most issues are component-specific rather than coordination problems.

**Start with the big picture:** `make status` shows all components and their health.

**Drill down to specifics:** If a component is stuck, `kubectl describe kustomization component-registry -n flux-system` will show exactly what's happening.

The key difference from manual coordination debugging: you're debugging individual component behavior, not trying to figure out why services can't find each other.

## What Just Changed for You

You've experienced the fundamental shift that makes complex development environments manageable. Remember that registry deployment failure at the beginning? That coordination chaos is now completely eliminated.

**Before this tutorial:** You were stuck playing dependency detective, guessing what needed to be deployed first, juggling different tools, debugging half-broken environments, and spending more time on service coordination than actual development work.

**After this tutorial:** You can deploy complete development environments with one command, automatic dependency resolution handles all the complexity, clean removal respects dependencies in reverse order, and you have zero coordination overhead so you can focus on building instead of infrastructure.

**The transformation:** Software stacks move multi-service environments from coordination nightmares into simple, reliable platforms. The same pattern scales whether you need 5 services or 50.

### Understanding the Building Blocks

You've been using pre-built components throughout this tutorial - the certificate manager, container registry, and ingress controller that make up your stack's foundation. These components are the building blocks that eliminate coordination chaos.

But what if you need different components? What if you want to understand how these building blocks actually work, or need to create custom ones for your specific requirements?

The components you've been deploying follow specific patterns and conventions that make them composable and reusable. Understanding these patterns is the key to building sophisticated development environments that go beyond the tutorial examples.

**The next step:** Learning to build and customize the components that power your stacks.

👉 **Continue to:** [Building Components](components.md) - *Learn how to create the reusable building blocks that power software stacks*
