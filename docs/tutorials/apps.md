# Deploying Applications

*Understanding HostK8s application patterns and why they eliminate deployment complexity*

## From Infrastructure to Applications

In the previous tutorial, you experienced how HostK8s eliminates Kubernetes infrastructure complexity through cluster configuration patterns. Now you face the next challenge: **what you deploy on that infrastructure**.

Just as managing raw Kubernetes infrastructure creates complexity chaos, traditional application deployment recreates the same problems at the application layer:

- **Deployment chaos** - Dozens of YAML files to track, apply in the right order, and manage individually
- **Environment inconsistency** - Hard-coded values that work locally but break in different environments
- **Team conflicts** - Developers stepping on each other's ports and configurations
- **Resource waste** - Every application deploying its own copy of identical infrastructure services

HostK8s addresses these through software application patterns just like it did with cluster configuration patterns in the previous tutorial. It provides consistent interfaces via the application contract, declarative configuration, and abstraction that lets you focus on what your applications do rather than how they deploy.

---

## Understanding HostK8s Applications

Let's start by getting our cluster running and deploying a simple application to understand what makes it work:

```bash
# Start your cluster with ingress capabilities
export INGRESS_ENABLED=true

make start
make deploy simple
make status
```

### Anatomy of a HostK8s Application

Explore the files of the [`simple`](../../software/apps/simple/) app:
```
simple
    ├── app.yaml
    ├── configmap.yaml          # Application configuration and content
    ├── deployment.yaml         # Pod specification and runtime behavior
    ├── ingress.yaml            # External access and routing rules
    ├── kustomization.yaml      # HostK8s application contract
    └── service.yaml            # Internal networking and discovery
```

The critical file is the `kustomization.yaml` file which creates an Application Contract around four HostK8s capabilities that enable `make deploy`.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: simple
  labels:
    hostk8s.app: simple
resources:
  - deployment.yaml
  - configmap.yaml
  - service.yaml
  - ingress.yaml
labels:
  - pairs:
      hostk8s.app: simple
```

| Capability | How It Works | Why It Matters |
|------------|--------------|----------------|
| **Unified Identity** | Names the app `simple` | Single name for all operations |
| **Automatic Discovery** | Lists all required files | No manual tracking of resources |
| **Resource Labeling** | Applies `hostk8s.app: simple` to everything | `make status` finds all pieces instantly |
| **Lifecycle Management** | Groups resources for operations | `make remove` cleans up completely |

**The key insight:**

HostK8s queries Kubernetes for all resources with `hostk8s.app: simple`, giving a unified status, deployment, and cleanup process from a single application name, regardless of the complexity.

---

## Multi‑Service Applications

The simple app demonstrated the kustomization contract, but real applications rarely consist of a single service. Let's see how HostK8s handles multi-service architectures by deploying the `basic` app:

```bash
# Deploy the basic application

make deploy basic
make status
```

You'll see:
```
📱 basic
   Deployment: api (2/2 ready)
   Deployment: frontend (2/2 ready)
   Service: api (ClusterIP)
   Service: frontend (ClusterIP)
   Ingress: app2-ingress -> http://localhost:8080/frontend

📱 simple
   Deployment: sample-app (2/2 ready)
   Service: sample-app (NodePort)
   Ingress: sample-app -> http://localhost:8080/simple
```

**Multiple applications, no conflicts.** Both applications coexist successfully in the same `default` namespace because the developers intentionally designed them with different resource names, ports, and ingress paths. When developers coordinate their application designs to avoid conflicts, multiple apps can share the same namespace.

Within the `basic` app, you can see how **internal and external service communication paths** work—the frontend calls the API service internally using Kubernetes DNS (`api.<namespace>.svc.cluster.local`), while only the frontend is exposed externally through the ingress.

**So far so good:** We've successfully deployed multiple applications in the same namespace. But what if we want to deploy the **same application** in different namespaces? This is a common need for team isolation, feature branch testing, or environment-specific deployments.

### HostK8s Namespace Convention

Running everything in the same namespace works for simple testing, but real development teams need **isolation**. HostK8s supports this through a namespace convention:

```bash
make deploy <app> <namespace>    # Deploy to custom namespace
```

For example:
- `make deploy basic feature` → namespace `feature`
- `make deploy basic test` → namespace `test`

This enables isolation, parallel environments, and safe experimentation. Let's try it:

```bash
make deploy basic feature
```

---

## The Static YAML Wall: When the Convention Breaks

**You'll hit this error:**
```
[15:00:35] Creating namespace: feature
namespace/feature created
[15:00:35] Using Kustomization deployment (preferred)

Error from server (BadRequest): the namespace from the provided object "default"
does not match the namespace "feature". You must pass '--namespace=default'
to perform this operation.

❌ Failed to deploy basic via Kustomization to feature
```

**What happened:** HostK8s created the `feature` namespace and tried to deploy there, but the `basic` app's kustomization.yaml specifies `namespace: default`:

```yaml
# basic/kustomization.yaml - STATIC NAMESPACE
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: basic
namespace: default  # ← Controls all resources
resources:
  - frontend-deployment.yaml
  # ... other files
```

### Understanding Kustomization's Namespace Capability

**How it works:** Kustomize's `namespace` field overrides the namespace for all resources, even if they had hardcoded values. This is actually a powerful feature - you could edit `kustomization.yaml` to say `namespace: feature` and redeploy.

**The real limitation:** Static configuration files can't respond to **dynamic deployment contexts**. HostK8s needs to support `make deploy basic feature` with the same static files, but the kustomization file can't adapt to command-line arguments.

To deploy to different namespaces, you'd need to:
1. Edit `kustomization.yaml` to change `namespace: default` → `namespace: feature`
2. Deploy the modified version

This is the core problem that leads teams to complex workarounds:
- **Kustomize overlays** - Create `overlays/feature/kustomization.yaml` that sets different namespaces
- **Manual file editing** - Change kustomization files for each deployment
- **Separate app copies** - Maintain different versions for different environments
- **Custom scripts** - Build deployment automation to modify files
- **Avoiding isolation** - Just deploy everything to default and accept conflicts

For configuration capabilities, see the [Kustomization Guide](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/).

What we need is **template-based configuration** that can adapt at deployment time, accepting parameters like namespace, environment, and release name without requiring file modifications.

**You'll hit this error:**
```
[15:00:35] Creating namespace: feature
namespace/feature created
[15:00:35] Using Kustomization deployment (preferred)

Error from server (BadRequest): the namespace from the provided object "default"
does not match the namespace "feature". You must pass '--namespace=default'
to perform this operation.

❌ Failed to deploy basic via Kustomization to feature
```

**What happened:** HostK8s created the `feature` namespace and tried to deploy there, but every YAML file in the `basic` app has a hardcoded `namespace: default`:

```yaml
# basic/frontend-deployment.yaml - HARDCODED NAMESPACE
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: default  # ← Can't be changed!
```

**The fundamental limitation:** Static YAML files can't adapt to different deployment contexts. When you need team isolation, feature branch testing, or environment-specific deployments, kustomization-based apps hit an inflexibility wall.

---

## Breaking Through the YAML Wall with Helm

Static YAML files can't adapt to different deployment contexts. When you need team isolation, feature branch testing, or environment-specific deployments, you need **dynamic configuration**.

This is where Helm templates shine—they provide deployment-time flexibility while maintaining the same `make deploy` simplicity. You get the power of dynamic configuration without losing the ease of consistent commands.

### The Voting Application: Helm in Action

```bash
make remove basic main-branch
make remove basic feature-api-changes
make deploy advanced
make status
```

Visit http://localhost:8080/vote — multi‑service, production‑ready.

---

## How Helm Fixes Ingress Conflicts

Deploy multiple instances:

```bash
make deploy advanced feature-new-architecture
make deploy advanced main-stable
```

Check ingress paths:
- http://localhost:8080/vote → original
- http://localhost:8080/feature-new-architecture/vote → feature
- http://localhost:8080/main-stable/vote → main

**Why unique?** The ingress template uses `{{ .Release.Name }}`:

```yaml
- path: /{{ .Release.Name }}/vote(/|$)(.*)
```

→ Helm fills in `feature-new-architecture` or `main-stable`, producing unique routes. Same chart, different deployments.

---

## Environment-Specific Configuration

Helm supports **per-environment configuration overrides** via values files:

```bash
make deploy advanced feature-new-architecture dev
make deploy advanced main-stable staging
```

`values/development.yaml`:

```yaml
vote:
  replicas: 1
  resources:
    requests:
      memory: "128Mi"  # More memory in dev
```

Overrides apply per release without hard‑coding.

---

## Interface Consistency

Regardless of complexity:

```bash
make deploy simple
make deploy basic alice
make deploy advanced staging
```

📌 **Same commands, any complexity**: that's the HostK8s abstraction.

---

## The Hidden Cost of Isolation

While Helm solves configuration flexibility, it reveals another challenge. Run this command to see what's happening with shared infrastructure:

```bash
kubectl get deployments --all-namespaces | grep -E "(redis|db)"
```

Notice anything? Each voting app deployment runs its own Redis and database instances—that's resource waste and operational overhead multiplied by every environment.

---

## Building from Source Code

Beyond deploying pre-built applications, HostK8s also handles the complete source-to-deployment workflow:

```bash
make build src/registry-demo
make deploy registry-demo
make status
```

1. Source → image in registry
2. Deploy → app in Kubernetes

---

## Application Architecture Progression

```
Static YAML → Multi-Service YAML → Helm Templates
```

- Static: simple, limited flexibility
- Multi‑Service: introduces service interaction patterns but creates configuration conflicts
- Helm: fixes config conflicts, enables environments, but duplicates infra

---

## Key Takeaways

You've experienced the evolution of Kubernetes application deployment:

- **Static YAML**: Simple but inflexible—breaks when you need multiple environments
- **Helm Templates**: Solves configuration conflicts and enables per-environment customization
- **The Trade-off**: Flexibility comes at the cost of infrastructure duplication

The Application Contract Pattern ensures consistent deployment commands regardless of underlying complexity, but shared infrastructure remains a challenge.

**Next**: Learn how to share infrastructure components (like Redis) across applications while maintaining environment isolation.

👉 **Continue to:** [Using Components](shared-components.md)
