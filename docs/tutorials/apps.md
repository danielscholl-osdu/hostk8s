# HostK8s Application Patterns

Learn application deployment through hands-on experience with three real apps that demonstrate the natural evolution from simple Kubernetes deployments to sophisticated Helm charts. This tutorial shows *why* different patterns exist by letting you experience the limitations that drive adoption of more advanced approaches.

## The Learning Journey

We'll explore three applications that represent the typical evolution of Kubernetes deployments:

- **`simple`** - Single-service web app using basic Kustomization
- **`basic`** - Multi-service app that reveals Kustomization limitations
- **`advanced`** - Complex voting app using Helm charts for flexibility

Each app builds on lessons from the previous one, showing you the real problems that drive architectural decisions. You'll experience port conflicts, environment configuration challenges, and resource management issues - then see how each approach solves these problems.

## Prerequisites

Ensure you have a HostK8s cluster with ingress capabilities:

```bash
export INGRESS_ENABLED=true
export METALLB_ENABLED=true
make start
```

## Level 1: Simple Applications

### Understanding the Basics

Let's start with the simplest possible application - a single web service that displays a static page. This demonstrates core Kustomization concepts without complexity.

Deploy the simple application:

```bash
make deploy simple
```

Check the deployment status:

```bash
make status
```

You'll see:
```
📱 simple
   Deployment: sample-app (2/2 ready)
   Service: sample-app (NodePort, NodePort 30081)
   Ingress: sample-app -> http://localhost:8080/simple
```

Visit http://localhost:8080/simple to see the running application.

### Examining the Simple App Structure

Let's look at what makes this work:

```bash
# View the app structure
ls software/apps/simple/
```

You'll see:
```
README.md
app.yaml           # All-in-one resource definition
configmap.yaml     # Static HTML content
deployment.yaml    # Pod specification
ingress.yaml       # External access rules
kustomization.yaml # HostK8s integration
service.yaml       # Networking
```

The `kustomization.yaml` file is what makes this a HostK8s app:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: simple
  labels:
    hostk8s.app: simple

resources:
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml

labels:
  - pairs:
      hostk8s.app: simple
```

This contract tells HostK8s:
- **Identity**: The app is named "simple"
- **Resources**: Which YAML files comprise the application
- **Management**: Apply consistent labels for unified operations

### Working with Namespaces

HostK8s provides flexible namespace management for team collaboration and environment isolation.

**Default namespace (clean display):**
```bash
make deploy simple              # Deploys to 'default'
```

**Custom namespace (explicit):**
```bash
make deploy simple testing      # Deploys to 'testing' namespace
```

**Environment variable:**
```bash
NAMESPACE=development make deploy simple
```

Try deploying to a custom namespace:

```bash
make deploy simple testing
make status
```

Notice how the status display shows the namespace:
```
📱 testing.simple
   Deployment: sample-app (2/2 ready)
   ...
```

This `namespace.app` format makes it immediately clear where each application is running.

## Level 2: Multi-Service Applications

### Discovering Limitations

The `simple` app works great for single services, but what happens when you need multiple services? Let's explore the `basic` app - a two-service application with a frontend and API.

First, let's clean up our testing namespace:

```bash
make remove simple testing
```

Deploy the basic application:

```bash
make deploy basic
make status
```

You'll see a more complex deployment:
```
📱 basic
   Deployment: api (1/1 ready)
   Deployment: frontend (1/1 ready)
   Service: api (ClusterIP, internal only)
   Service: frontend (NodePort, NodePort 30082)
   Ingress: basic -> http://localhost:8080/basic
```

Visit http://localhost:8080/basic to see the frontend communicating with the API service.

### Hitting Real-World Problems

Now let's experience the limitations that drive people toward more advanced solutions. Try deploying both apps simultaneously:

```bash
# This should fail with conflicts
make deploy simple
```

You'll see errors like:
```
Service "sample-app" is invalid: spec.ports[0].nodePort: Invalid value: 30081: provided port is already allocated
```

This demonstrates a key limitation of static Kustomization: **port conflicts**. Both apps try to use the same NodePort, causing deployment failures.

### Environment Configuration Challenges

The problems get worse when you need different configurations for different environments. Look at the basic app's deployment - it has hard-coded resource limits:

```bash
# View the hard-coded values
grep -A 5 "resources:" software/apps/basic/api-deployment.yaml
```

What if you need different resource limits for development vs. production? With static Kustomization, you'd need separate files or complex overlays.

### Namespace Conflicts and Team Collaboration

Let's simulate a team environment where multiple developers work on the same app:

```bash
# Deploy basic app to different "developer" namespaces
make deploy basic alice
make deploy basic bob
make status
```

You'll see:
```
📱 alice.basic
   Deployment: api (1/1 ready)
   ...
📱 bob.basic
   Deployment: api (1/1 ready)
   ...
```

This works because namespaces provide isolation, but notice the limitations:
- Both deployments use identical configurations
- Resource limits are the same regardless of developer needs
- Port assignments are managed by Kubernetes, not by developer preference

## Level 3: Advanced Applications with Helm

### The Solution to Flexibility Problems

Now let's see how Helm charts solve the configuration and flexibility problems we've experienced. The `advanced` app is a complete voting application that uses Helm templating.

First, clean up our test deployments:

```bash
make remove basic alice
make remove basic bob
make remove basic
```

Deploy the advanced Helm-based application:

```bash
make deploy advanced
make status
```

You'll see a much more complex application:
```
📱 advanced (Helm Chart: helm-sample-0.1.0, App: , Release: advanced)
   Deployment: db (1/1 ready)
   Deployment: redis (1/1 ready)
   Deployment: result (1/1 ready)
   Deployment: vote (1/1 ready)
   Deployment: worker (1/1 ready)
   Service: db (ClusterIP, internal only)
   Service: redis (ClusterIP, internal only)
   Service: result (ClusterIP, internal only)
   Service: vote (ClusterIP, internal only)
   Ingress: advanced-helm-sample -> http://localhost:8080/vote
```

Visit http://localhost:8080/vote to interact with the full voting application.

### Multiple Environments Without Conflicts

Now here's the power of Helm - deploy the same application to different environments with different configurations:

```bash
# Deploy to development environment (uses development values)
make deploy advanced dev

# Deploy to staging with different configuration
make deploy advanced staging

make status
```

You'll see:
```
📱 dev.helm-sample (Helm Chart: ...)
   ...
📱 staging.helm-sample (Helm Chart: ...)
   ...
```

Each deployment gets its own resources, ports, and configurations - no conflicts!

### Understanding Helm's Flexibility

Let's examine what makes this possible. Look at the Helm chart structure:

```bash
ls software/apps/advanced/
```

You'll see:
```
Chart.yaml                # Chart metadata
values.yaml              # Default configuration
values/
  development.yaml       # Development overrides
  production.yaml        # Production overrides
templates/               # Template files
  vote-deployment.yaml   # Templated resources
  db-service.yaml
  ...
```

**Templates solve the hard-coding problem:**

```bash
# View a template file
head software/apps/advanced/templates/vote-deployment.yaml
```

You'll see templated values like:
```yaml
replicas: {{ .Values.vote.replicas }}
image: "{{ .Values.vote.image.repository }}"
resources:
  requests:
    memory: "{{ .Values.vote.resources.requests.memory }}"
```

**Values files provide environment-specific configuration:**

```bash
# Compare default vs development values
grep -A 5 "memory" software/apps/advanced/values.yaml
grep -A 5 "memory" software/apps/advanced/values/development.yaml
```

Development environments get higher memory limits to handle debugging tools and verbose logging.

## Real-World Team Workflows

### Individual Developer Isolation

Each team member can work on their own version without conflicts:

```bash
# Alice works on feature development
make deploy advanced alice

# Bob tests a different configuration
NAMESPACE=bob-testing make deploy advanced

make status
```

You'll see:
```
📱 alice.helm-sample (Helm Chart: ...)
📱 bob-testing.helm-sample (Helm Chart: ...)
📱 dev.helm-sample (Helm Chart: ...)
📱 staging.helm-sample (Helm Chart: ...)
```

Each developer gets complete isolation with their own databases, Redis instances, and configurations.

### Environment Progression

The same application can progress through environments:

```bash
# Development (low resources, debug enabled)
make deploy advanced development

# Staging (production-like resources)
make deploy advanced staging

# Production would use production values
# NAMESPACE=production make deploy advanced
```

### Easy Cleanup

Remove specific deployments without affecting others:

```bash
# Clean up Alice's development work
make remove advanced alice

# Remove staging environment
make remove advanced staging

make status  # Others remain running
```

Empty namespaces are automatically cleaned up.

## Choosing the Right Pattern

### When to Use Each Approach

**Simple (Kustomization)**:
- Single-service applications
- Proof-of-concepts and demos
- Static configurations that don't vary by environment
- Learning Kubernetes basics

**Basic (Multi-service Kustomization)**:
- Multi-service applications with simple architectures
- Internal tools where configuration flexibility isn't critical
- When you need service communication patterns but not templating

**Advanced (Helm Charts)**:
- Applications that deploy to multiple environments
- Complex multi-service architectures
- When you need environment-specific configurations
- Team collaboration requiring isolation
- Production applications requiring flexibility

### Evolution Path

Most applications follow this natural progression:

1. **Start Simple**: Begin with static Kustomization for quick prototyping
2. **Hit Limitations**: Experience port conflicts, configuration inflexibility
3. **Graduate to Helm**: Adopt templating for multi-environment deployments
4. **Scale with Teams**: Use namespaces for developer and environment isolation

You can always migrate applications between patterns as requirements change.

## Next Steps

Now that you understand application patterns, explore other HostK8s capabilities:

### GitOps Automation

Move beyond manual deployment to automated GitOps workflows:

```bash
make up sample  # Deploy complete software stack with Flux
```

### Infrastructure Extensions

Customize cluster capabilities for specific requirements:

```bash
# Custom cluster configurations
export KIND_CONFIG=extension/gpu-enabled
make start

# Custom software stacks
make up extension/my-stack
```

### Development Integration

Build and deploy custom applications:

```bash
# Build from source
make build src/my-app

# Deploy to development environment
make deploy my-app development
```

The patterns you've learned - namespace management, environment-specific configurations, and application isolation - apply to all HostK8s deployment methods.

## Summary

You've experienced the natural evolution of Kubernetes application deployment:

- **Simple apps** provide immediate deployment capabilities with basic Kustomization
- **Multi-service apps** reveal limitations around port conflicts and configuration inflexibility
- **Helm charts** solve these problems with templating and environment-specific values
- **Namespace management** enables team collaboration and environment isolation

This progression mirrors real-world application development, where requirements evolve from simple prototypes to production-ready systems. HostK8s supports this entire journey with consistent tooling and patterns.
