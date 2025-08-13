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

This is a typical coordination problem. The registry component requires a TLS certificate for secure connections, but to provision certificates we need certificate issuers, and to manage those issuers we need cert-manager deployed first. Kustomizations only define *what* to deploy, not *when* - there's no built-in mechanism to enforce this multi-step dependency chain (cert-manager → certificate issuer → certificate → registry).

Now imagine this same experience multiplied across 5-10 foundational components, each with their own assumptions about what should already be running. You'd spend more time figuring out deployment order and debugging cryptic errors than actually building applications.

### The Natural Response: DIY Orchestration

When projects hit this coordination wall, they naturally start creating their own orchestration. You've probably seen this before: **'Magic README' files** with step-by-step procedures that say "run this command, verify the output shows 'Ready', then copy-paste the next block and wait for completion," or **bash scripts** with sleep commands, excessive or not enough logging and crossed fingers hoping services are actually ready before continuation.


These DIY solutions work sometimes, but create a bigger architectural problem: **tight coupling**. Your setup script becomes a monolithic sequence bound to your specific environment. Want to work on just the monitoring component? You can't because you have to run through the entire process first. This tight coupling makes development painful because you can't isolate your work.

This coordination chaos is exactly why individual application deployment worked smoothly in the previous tutorial, but multi-service solutions become nightmares to manage manually.

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

Components solve the modularity problem. Stacks solve the coordination problem. Together, they transform multi-service chaos into manageable, reusable software solutions.

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

## Building Your Software Stack

Let's create a complete software solution. You'll see how the stack "instruction booklet" approach eliminates all the coordination chaos you just experienced.

### Your Software Stack Components

We'll examine a stack with essential components that work together. Certificate management provides HTTPS capabilities that modern web applications require. An ingress controller handles external traffic routing to your applications. Sample applications demonstrate how business logic connects to the foundation components.

Together, these components create a complete web application platform that eliminates the coordination chaos you experienced manually.

## Understanding Stack Structure

Let's examine a working stack to understand how it eliminates the coordination chaos you just experienced:

```bash
# Deploy the sample stack and explore its structure
make up sample
make status
```

### Anatomy of a Software Stack

Just like we explored the anatomy of HostK8s applications, let's examine what makes a stack work. Explore the files of the sample stack:

```
sample/
├── kustomization.yaml          # Stack contract (table of contents)
├── repository.yaml             # Source Location
├── stack.yaml                  # Orchestration configuration
├── components/                 # Stack-specific components
│   └── ...
└── applications/               # Stack-specific applications
    └── ...
```

### The Stack Contract

Similar to applications stacks need specific files to work with `make up`. The stack contract consists of three core files:

| File | Purpose | What It Enables |
|------|---------|-----------------|
| `kustomization.yaml` | Table of contents | Stack discovery and deployment |
| `repository.yaml` | Flux GitRepository declaration | Defines Git repo location for components |
| `stack.yaml` | Flux Kustomization declarations | Enhanced kustomize with sequencing and health checks |

### Component Flexibility

Stacks can mix components from multiple sources:

**External Components** (from other repositories):
- Specialized databases, custom monitoring, third-party services
- Teams can maintain component libraries in separate repositories
- Referenced via `repository.yaml` configurations

**Stack-Specific Components** (in `components/`):
- Custom configurations that don't belong in shared libraries
- Stack-specific tweaks to standard components
- Specialized components unique to this environment

**Shared hostk8s Components** (from `software/components/`):
- Certificate management, container registry, monitoring
- Maintained centrally, reused across multiple stacks
- Located in the main HostK8s repository


This flexibility means your stack can pull the PostgreSQL component from your team's database repository, the monitoring from a shared infrastructure repository, and include a custom authentication component specific to this application.

Let's examine how these pieces work together:

**1. Stack Table of Contents (`kustomization.yaml`):**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - repository.yaml    # Component source configuration
  - stack.yaml         # Orchestration dependencies
```

**2. Component Source Configuration (`repository.yaml`):**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 5m
  url: https://community.opengroup.org/danielscholl/hostk8s  # Can be any Git repo
  ref:
    branch: main
  ignore: |
    # exclude all
    /*
    # include only shared components
    !/software/components/
```

**3. Orchestration Dependencies (`stack.yaml`):**
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
  name: component-certs-ca
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs                  # Wait for cert-manager first
  path: ./software/components/certs-ca
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs-issuer
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs-ca               # Wait for certificate authority
  path: ./software/components/certs-issuer
  wait: true
```

### How Dependency Declarations Work

Looking at the certificate chain example above, notice how each Flux Kustomization declares two critical properties:

| Property | Purpose | Example |
|----------|---------|---------|
| path | Where to find the component | `./software/components/certs-ca` |
| dependsOn | What must be healthy first | `component-certs` |

This declarative approach eliminates the coordination chaos you experienced manually. Instead of guessing timing and deployment order, each component simply declares its dependencies and Flux automatically creates the execution plan: `certs → certs-ca → certs-issuer`.

This is exactly the dependency sequence that eliminates the coordination problem you hit when trying to deploy the registry manually.

### Experience the Stack Solution

You've already deployed the sample stack, let's examine what the GitOps automation actually did when you ran `make status`.

The output shows the dependency orchestration in action:

```
[OK] Kustomization: component-certs
   Ready: True
   Message: Applied revision: main@sha1:4ce8b6ba

[...] Kustomization: component-certs-ca
   Ready: False
   Message: dependency 'flux-system/component-certs' is not ready

[WAITING] Kustomization: component-certs-issuer
   Ready: False
   Message: dependency 'flux-system/component-certs-ca' is not ready
```

**Understanding the Kustomization States:**

| Status | Meaning | What's Happening |
|--------|---------|------------------|
| [OK] | Component is healthy and ready | Dependencies satisfied, resources deployed successfully |
| [WAITING] | Blocked by dependencies | Component waits for its dependencies to become ready |
| [...] | Reconciliation in progress | Flux is actively deploying or updating the component |

**What you're witnessing:** This is the exact dependency sequence we defined (`certs → certs-ca → certs-issuer`) being automatically enforced by Flux. Instead of the coordination chaos you experienced manually - guessing deployment order, waiting and hoping things are ready, debugging circular dependencies - the stack handles all that intelligence automatically.

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
