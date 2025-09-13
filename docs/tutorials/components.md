# Understanding Components

*Learn how components eliminate duplication and provide reusable software capabilities*

## The Software Duplication Problem

In the stacks tutorial, you deployed a complete solution using Flux. But what happens when you're building multiple microservices or a platform? In practice, services don't operate in complete isolation - they share foundational capabilities like load balancers, DNS resolution, certificate management, and often databases or caching layers.

The challenge isn't whether to share these capabilities, but **how to manage the shared ones effectively**. Consider three microservices in a typical web application architecture:

- **Web service**: Frontend that calls the API, needs certificates and DNS routing
- **API service**: Handles requests and queues jobs, needs certificates, database access, and Redis for job queues
- **Worker service**: Processes background jobs, needs database access and Redis for job queues

Each service could define its own certificate issuer, DNS configuration, and Redis instance. But this means every stack developer must become an expert in properly configuring cert-manager, setting up a certificate authority, configuring Redis for use, providing access, insights, and the right amount of compute and memory.

## What Is a Component?

> 💡 **Definition**: A component is a pre-configured software capability that stacks can declare they need. Components solve the expertise and reliability problem by packaging the knowledge of proper setup for complex software (like certificate management or databases) into working, tested declarative building blocks that stack developers can easily consume without becoming experts in the underlying implementation.

Components are reusable across multiple stacks. They focus on software capabilities. Each component packages everything needed for that capability, whether that's Helm charts, plain Kubernetes manifests, operators, or custom resources. Flux deploys them automatically through declarative GitOps - you declare what you want in configuration rather than orchestrating imperative activities like `helm install` or `kubectl apply`.

This creates a clear separation of concerns: components provide reusable software capabilities like Redis or certificates, and stacks compose components and applications into complete platform solutions.

## The Simple Component Pattern

Before examining complex components, let's understand the basic pattern. Most components are surprisingly simple - they're just Kubernetes resources packaged for Flux to deploy automatically.

Remember in the apps tutorial when you ran `make deploy advanced`? That command executed `helm install` to deploy the Helm chart. A simple component can do the same thing - it declares those same resources for Flux rather than you triggering a deployment manually at the right point in time.

Here's a common component pattern using Helm:

```
simple-component/
├── kustomization.yaml     # Component definition
├── source.yaml            # Helm repository (like "helm repo add")
├── release.yaml           # Helm chart (like "helm install")
└── ingress.yaml           # Optional: external access
```

But components aren't limited to Helm. They can also be:
- Plain Kubernetes manifests (deployments, services, config maps)
- Custom resources (operators, CRDs)
- Any combination of Kubernetes resources

## Component Complexity Spectrum

### The Dependency Problem

Most components are simple, but some capabilities require **multiple steps that must happen in order**. This is where components become powerful orchestrators.

Consider certificates: you can't just install a certificate. You need:
1. **cert-manager** (the certificate management system)
2. **Certificate Authority** (to sign certificates)
3. **Certificate Issuer** (to handle certificate requests)

Only then can applications request certificates. Each step depends on the previous one being ready. This is exactly what Flux's `dependsOn` feature solves.

### Component as Orchestrator

The certificate component handles this dependency chain automatically:

```
certs/
├── kustomization.yaml      # Component entry point
├── component.yaml          # Orchestrates the dependencies
├── manager/                # Step 1: Install cert-manager
├── ca/                     # Step 2: Create certificate authority
└── issuer/                 # Step 3: Create certificate issuer
```

You can examine how this dependency orchestration works in [`software/components/certs/component.yaml`](../../software/components/certs/component.yaml).

### Beyond Helm Charts

Notice something important: **components aren't limited to Helm charts**. Each subdirectory (manager/, ca/, issuer/) contains different types of Kubernetes resources:
- **manager/**: Helm chart installation
- **ca/**: Plain Kubernetes Certificate resource
- **issuer/**: Plain Kubernetes ClusterIssuer resource

**Components can orchestrate any Kubernetes resources** - Helm charts, individual manifests, or even other components.

## Bridge to Development

Now you understand how components eliminate the expertise burden and provide pre-configured software capabilities that stacks can declare they need. Components package complex software setup (from simple Helm charts to orchestrated dependency chains) into reliable building blocks.

In the next tutorial, you'll learn how to develop applications within this component-based infrastructure, including hybrid workflows that bridge local development with Kubernetes deployment.

👉 **Continue to:** [Development Workflows](development.md) - *Learn how to build applications that use the shared components you now understand*
