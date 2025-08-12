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

The `simple` app demonstrated the kustomization contract, but real applications are typically multi-service and often need to coexist with other applications in the same namespace. Let's see how HostK8s handles this by deploying the `basic` app:

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

Within the `basic` app, you can see how internal and external service communication paths work. The frontend calls the API service internally using Kubernetes DNS (`api.<namespace>.svc.cluster.local`), while only the frontend is exposed externally through the ingress.

**So far so good:** We've successfully deployed multiple applications in the same namespace. But what if we want to deploy the same application in different namespaces? This is a common need for team isolation, feature branch testing, or environment-specific deployments.

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
# Deploy the basic app in the feature namespace

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

**What happened:** HostK8s created the `feature` namespace and tried to deploy there, but the `basic` app's kustomization.yaml directly specified `namespace: default`:

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

**How it works:** Kustomize's `namespace` field overrides the namespace for all resources, even if they had hardcoded values. This is actually a powerful feature. You could edit `kustomization.yaml` to say `namespace: feature` and redeploy.

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

### Why Static YAML Hits a Wall

**We just hit the complexity wall:** While Kustomize offers overlays, patches, and cross-cutting fields to handle deployment-time parameters like namespace, environment, or replica counts, it requires complex directory structures, patch files, and careful configuration management.

This becomes cumbersome when teams need isolation through separate namespaces, feature branch preview deployments, or different configurations across dev, staging, and production environments. Kustomize solutions require overlay directories, strategic merge patches, and structured file hierarchies that make deployment management complex compared to simpler approaches.

**What we need is template-based configuration** that accepts deployment-time parameters without modifying source files. Instead of static file juggling, we need a clean parameter contract.

---

## Breaking Through the YAML Wall with Helm

Static YAML files can't adapt to different deployment contexts. When you need team isolation, feature branch testing, or environment-specific deployments, you need **dynamic configuration**.

This is where Helm templates shine. They provide deployment-time flexibility while maintaining the same `make deploy` simplicity. You get the power of dynamic configuration without losing the ease of consistent commands.

### The Voting Application: Helm in Action

```bash
# Restart the Cluster and enable both AddOns
export INGRESS_ENABLED=true
export METALLB_ENABLED=true

make restart
make deploy advanced
make deploy advanced feature
make status
```

Two isolated environments from the same chart - exactly what failed with static YAML. The Helm templates adapt automatically, giving you a default environment at http://localhost:8080/ and a feature environment at http://feature.localhost:8080/. Same chart, same commands, different environments working seamlessly together.

### Anatomy of a Helm Application Contract

Just like Kustomization apps need a specific structure to work with `make deploy`, Helm charts must follow an Application Contract. Explore the [`advanced`](../../software/apps/advanced/) app structure:

```
advanced/
├── Chart.yaml              # Helm chart metadata and version
├── values.yaml             # Default configuration values
├── templates/              # Dynamic Kubernetes manifests
│   ├── _helpers.tpl        # Template helper functions
│   ├── frontend-deployment.yaml
│   ├── backend-deployment.yaml
│   ├── ingress.yaml
│   └── ...
```

### Making Helm Charts Work with HostK8s

For a Helm chart to work with `make deploy` and `make status`, the chart developer must follow the **HostK8s Helm Contract**:

#### Required: Chart Structure
```yaml
# Chart.yaml (tells HostK8s to use Helm)
apiVersion: v2
name: advanced
description: A HostK8s Advanced Sample
type: application
version: 0.1.0
```

#### Required: Resource Labels
Every Kubernetes resource must have the `hostk8s.app` label for `make status` to find them:

```yaml
# In your templates (deployment.yaml, service.yaml, etc.)
metadata:
  labels:
    hostk8s.app: advanced    # Must match your chart name
```

#### Implementation Example
The `advanced` chart implements this through a common labels helper:

```yaml
# templates/_helpers.tpl
{{- define "advanced.labels" -}}
hostk8s.app: advanced
# ... other standard labels
{{- end }}
```

Then every template uses `{{ include "advanced.labels" . }}` to apply the labels consistently.

**That's it.** Two requirements: Chart.yaml for detection, hostk8s.app labels for discovery. The chart handles everything else - HostK8s just provides the consistent `make deploy` interface.

### Chart Values Hierarchy

HostK8s Helm charts support a flexible values hierarchy that allows user-specific and environment-specific customization:

```
advanced/
├── values.yaml              # Base values (always used)
├── custom_values.yaml       # User overrides (optional, gitignored)
└── values/
    └── development.yaml     # Environment overrides (optional)
```

**Values loading order:**
1. **Base values**: `values.yaml` - Default chart configuration
2. **Custom values**: `custom_values.yaml` - User-specific overrides (if present)
3. **Environment values**: `values/development.yaml` - Environment overrides (if present)

This hierarchy allows developers to:
- **Customize locally**: Create `custom_values.yaml` for personal testing configurations
- **Override per environment**: Use `values/development.yaml` for consistent dev settings
- **Maintain defaults**: Keep `values.yaml` as the baseline configuration

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
