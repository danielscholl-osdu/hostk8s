# GitOps Software Stacks

This directory contains **Software Stack Patterns** for different deployment scenarios. "Stack" represents pre-configured complete software environments with consistent, declarative deployments across environments.

## Available Stacks

### `sample/` - GitOps Pattern Demonstration
- **Purpose**: Demonstrates component/application separation pattern
- **Components**: ingress-nginx, postgresql
- **Applications**: sample-api, sample-website
- **Use Case**: Learning GitOps patterns, development reference

### `sample-stack/` - (Future) Extended Sample
- **Purpose**: Extended sample with more components
- **Components**: TBD (istio, elasticsearch, postgresql, etc.)
- **Applications**: TBD (additional sample services)
- **Use Case**: Extended development scenarios

## Stack Selection

Control which stack is deployed via environment variables:

```bash
# Use sample stack (default)
export SOFTWARE_STACK=sample
make up sample

# Use sample-stack (when available)
export SOFTWARE_STACK=sample-stack
make up sample-stack

# Or set in .env file
SOFTWARE_STACK=sample
```

## Overview

Flux is a GitOps operator for Kubernetes that keeps your cluster in sync with Git repositories. Each stack provides:

- **Declarative deployments**: Infrastructure and applications defined in Git
- **Component separation**: Infrastructure (ingress, database) vs applications (API, web)
- **Automated deployments**: Changes in Git trigger cluster updates
- **Environment consistency**: Same stack pattern across dev/staging/prod

## Getting Started

### 1. Enable Flux

Enable Flux in your `.env` file:
```bash
FLUX_ENABLED=true
```

Or start cluster with Flux:
```bash
FLUX_ENABLED=true make start
```

### 2. Verify Installation

Check Flux controllers:
```bash
export KUBECONFIG=$(pwd)/data/kubeconfig/config
flux get all
kubectl get pods -n flux-system
```

### 3. Basic Usage

Flux will automatically create a demo GitRepository and Kustomization that deploys a sample application.

## Example Configurations

### GitRepository Source

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/your-username/your-app-repo
  ref:
    branch: main
```

### Kustomization Deployment

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 5m
  path: "./manifests"
  prune: true
  sourceRef:
    kind: GitRepository
    name: my-app
```

### Helm Release

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: nginx
  namespace: default
spec:
  interval: 5m
  chart:
    spec:
      chart: nginx
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
```

## Directory Structure

```
software/stacks/
├── README.md              # This file
├── sources/               # Git repositories and Helm repositories
│   ├── git-repository.yaml
│   └── helm-repository.yaml
├── apps/                  # Application deployments
│   ├── kustomization.yaml
│   └── helm-release.yaml
└── clusters/              # Cluster-specific configurations
    └── sample-stack/
        ├── infrastructure.yaml
        └── apps.yaml
```

## Commands

### Monitor Flux

```bash
# Watch all Flux resources
flux get all --watch

# Follow logs
flux logs --follow

# Check specific component
flux get sources git
flux get kustomizations
flux get helmreleases
```

### Troubleshooting

```bash
# Check reconciliation
flux reconcile source git my-app
flux reconcile kustomization my-app

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Flux status
flux check
```

## Integration with Sample Apps

You can deploy additional sample apps via GitOps:

1. Create a Git repository with your app manifests
2. Create a GitRepository pointing to your repo
3. Create a Kustomization to deploy the apps
4. Flux will automatically sync changes

## Best Practices

1. **Use Git branches** for different environments (dev, staging, prod)
2. **Separate repos** for infrastructure and applications
3. **Use Kustomize overlays** for environment-specific configurations
4. **Enable notifications** to stay informed of deployment status
5. **Set proper RBAC** for production clusters

## Resources

- [Flux Documentation](https://fluxcd.io/flux/)
- [GitOps Toolkit](https://fluxcd.io/flux/components/)
- [Flux2 Examples](https://github.com/fluxcd/flux2-kustomize-helm-example)
- [Best Practices](https://fluxcd.io/flux/guides/)
