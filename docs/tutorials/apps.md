# Deploying Applications

*Understanding HostK8s application patterns and why they eliminate deployment complexity*

## The Application Deployment Problem

You've configured your cluster architecture and experienced how HostK8s eliminates the complexity of managing Kubernetes infrastructure (from [Cluster Configuration](cluster.md)).
But infrastructure is just the foundation — the real challenge is **what you deploy on it**.

Traditional Kubernetes application deployment creates the same complexity problems that HostK8s solves at the infrastructure level:

- **Deployment chaos** - Dozens of YAML files to track, apply in the right order, and manage individually
- **Environment inconsistency** - Hard-coded values that work locally but break in different environments
- **Team conflicts** - Developers stepping on each other's ports and configurations
- **Resource waste** - Every application deploying its own copy of identical infrastructure services

HostK8s addresses these through **application patterns** just like it did with **cluster architecture patterns** in the last tutorial — providing consistent interfaces (*Application Contract Pattern*), declarative configuration, and *Complexity Abstraction* that lets you focus on functionality rather than mechanics.

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

The critical file is `kustomization.yaml` — this creates the **Application Contract Pattern** that makes `make deploy simple` work:

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

**This contract enables four key HostK8s capabilities:**

| Capability | How It Works | Why It Matters |
|------------|--------------|----------------|
| **Unified Identity** | Names the app `simple` | Single name for all operations |
| **Automatic Discovery** | Lists all required files | No manual tracking of resources |
| **Resource Labeling** | Applies `hostk8s.app: simple` to everything | `make status` finds all pieces instantly |
| **Lifecycle Management** | Groups resources for operations | `make remove` cleans up completely |

**The key insight:** HostK8s queries Kubernetes for all resources with `hostk8s.app: simple` — giving you unified status, deployment, and cleanup through a single application name, whether you're using static YAML or complex Helm charts.

---

## Multi‑Service Applications

Single‑service apps like `simple` demonstrate the contract, but most real apps use multiple cooperating services. Deploy the **basic** app to see how this works:

```bash
make deploy basic
make status
```

You'll see:
```
📱 basic
   Deployment: api (2/2 ready)
   Deployment: frontend (2/2 ready)
   Service: api (ClusterIP, internal only)
   Service: frontend (ClusterIP, internal only)
   Ingress: app2-ingress -> http://localhost:8080/frontend
```

This demonstrates the **internal vs external service** pattern — the frontend calls the API service internally using Kubernetes DNS (`api.<namespace>.svc.cluster.local`), while only the frontend is exposed externally through the ingress.

**Namespace Convention:** Each deployment runs in a separate Kubernetes namespace: `make deploy basic feature` → namespace `feature.basic`. This enables team isolation, parallel environments, and safe experimentation.

---

## Configuration Inflexibility: The Static YAML Wall

Let's deploy both applications together to see what works:

```bash
make deploy basic
make deploy simple
make status
```

You'll see both applications running successfully:
```
📱 basic
   Deployment: api (2/2 ready)
   Deployment: frontend (2/2 ready)
   Service: api (ClusterIP, internal only)
   Service: frontend (ClusterIP, internal only)
   Ingress: app2-ingress -> http://localhost:8080/frontend

📱 simple
   Deployment: sample-app (2/2 ready)
   Service: sample-app (NodePort, NodePort 30081 - not mapped to localhost)
   Ingress: sample-app -> http://localhost:8080/simple
```

**Why this works:** Different apps use different hard-coded values — no conflicts occur.

### Where Static YAML Breaks Down

Now try deploying the same app to a different namespace (a common development need):

```bash
make deploy basic feature
```

**You'll hit this error:**
```
[15:00:35] Creating namespace: feature
namespace/feature created
[15:00:35] Using Kustomization deployment (preferred)
the namespace from the provided object "default" does not match the namespace "feature".
You must pass '--namespace=default' to perform this operation.
❌ Failed to deploy basic via Kustomization to feature
```

**What happened:** HostK8s created the `feature` namespace and tried to deploy there, but every YAML file in the `basic` app has hardcoded `namespace: default`:

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

## Template‑Based Flexibility with Helm

Helm templates unlock **dynamic configuration** at deployment time while keeping the same `make deploy` simplicity — an example of the **Complexity Abstraction Pattern**.

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

## Multi‑Version with Environment Overrides

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

📌 **Same commands, any complexity** — that's the HostK8s abstraction.

---

## The Resource Duplication Problem

Run:

```bash
kubectl get deployments --all-namespaces | grep -E "(redis|db)"
```

Each voting app release has its own Redis & DB — resource waste + ops overhead.

---

## The Complete Workflow from Source

HostK8s also builds from source:

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
- Multi‑Service: introduces infra patterns + conflicts
- Helm: fixes config conflicts, enables environments, but duplicates infra

---

## Summary & What's Next

You've learned:

- **Application Contract Pattern**
- **Complexity Abstraction Pattern**
- Multi‑service infra separation
- Helm‑driven flexibility & environment overrides
- Source → registry → cluster workflow
- Trade‑off: flexibility vs infrastructure duplication

👉 **Continue to:** [Using Components](shared-components.md) — learn how to **share infrastructure** (like Redis) across apps while keeping environment isolation.
