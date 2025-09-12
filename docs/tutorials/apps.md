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
# Start your cluster (ingress is enabled by default)
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

The critical file is the `kustomization.yaml` file which creates an application contract around four HostK8s capabilities that enable `make deploy`.

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

Kustomize's `namespace` field can override the namespace for all resources, even if they had hardcoded values. You could edit the `basic` app's `kustomization.yaml` to change `namespace: default` to `namespace: feature` and redeploy successfully.

**The limitation:** Static configuration files can't respond to dynamic deployment contexts. HostK8s needs to support `make deploy basic feature` with the same static files, but the kustomization file can't adapt to command-line arguments.

**The workarounds:** This forces teams into complex solutions:
- Kustomize overlays with separate directories for each environment
- Multiple copies of applications for different contexts
- Custom scripts to modify files before deployment
- Avoiding namespace isolation altogether

While Kustomize provides powerful capabilities, these solutions require complex directory structures that make simple deployments unnecessarily complicated.

### Why Static YAML Hits a Wall

**We just hit the complexity wall:** While Kustomize offers overlays, patches, and cross-cutting fields to handle deployment-time parameters like namespace, environment, or replica counts, it requires complex directory structures, patch files, and careful configuration management.

**The real-world impact:** Teams need isolation through separate namespaces, feature branch preview deployments, and different configurations across environments. Kustomize solutions require overlay directories, strategic merge patches, and structured file hierarchies that make deployment management complex compared to simpler approaches.

What we need is template-based configuration that accepts deployment-time parameters without modifying source files. Instead of static file juggling, we need a clean parameter contract.

---

## Breaking Through the YAML Wall with Helm

Static YAML files can't adapt to different deployment contexts. When you need team isolation, feature branch testing, or environment-specific deployments, you need **dynamic configuration**.

This is where Helm templates shine. They provide deployment-time flexibility while maintaining the same `make deploy` simplicity. You get the power of dynamic configuration without losing the ease of consistent commands.

### Helm in Action

```bash
# Restart the Cluster (ingress is enabled by default)
make restart
make deploy advanced
make deploy advanced feature
make status
```

Two isolated environments from the same chart - exactly what failed with static YAML. The Helm templates adapt automatically, creating separate access points for each namespace. Same chart, same commands, different environments working seamlessly together.

### Anatomy of a Helm Application Contract

Just like Kustomization apps need a specific structure to work with `make deploy`, Helm charts must follow an Application Contract.

Explore the files of the [`advanced`](../../software/apps/advanced/) app:

```
advanced
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

For a Helm chart to work with `make deploy` and `make status`, the chart developer needs just two things:

**Chart.yaml file** - tells HostK8s to use Helm:
```yaml
apiVersion: v2
name: advanced
description: A HostK8s Advanced Sample
type: application
version: 0.1.0
```

**hostk8s.app labels** - applied to all Kubernetes resources for discovery:
```yaml
# In your templates (deployment.yaml, service.yaml, etc.)
metadata:
  labels:
    hostk8s.app: advanced    # Must match your chart name
```

The `advanced` chart implements this through a common helper template:

```yaml
# templates/_helpers.tpl
{{- define "advanced.labels" -}}
hostk8s.app: advanced
# ... other standard labels
{{- end }}
```

Every template then uses `{{ include "advanced.labels" . }}` to ensure consistent labeling across all resources. HostK8s handles the deployment mechanics while the chart controls its own resource structure and labeling strategy.

### Custom Values Support

HostK8s automatically looks for a `custom_values.yaml` file in your chart directory for local customization:

```
advanced/
├── values.yaml              # Default chart values
├── custom_values.yaml       # Your local overrides (gitignored)
```

If present, HostK8s loads custom_values.yaml after the base values, letting you override any configuration locally without modifying the original chart. This file is gitignored, so your personal customizations stay private while the chart remains shareable.

---

## What Comes Next

You've experienced HostK8s application deployment patterns, from static YAML limitations to Helm template flexibility. The same `make deploy` interface works regardless of application complexity, giving you consistent commands for any deployment scenario.

These application contracts form the foundation for software stack deployments. In the next tutorial, you'll:
- Build complete development environments using GitOps automation
- Coordinate multiple applications and infrastructure components
- Eliminate the operational overhead of managing individual deployments

The deployment patterns you've learned here will directly support the software stacks you'll compose next.

👉 **Continue to:** [Software Stacks](stacks.md)
