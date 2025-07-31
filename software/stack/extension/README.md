# Extension Software Stacks

This directory contains custom GitOps software stack configurations. Create your own software stacks here for version-controlled, repeatable development environments.

## Creating a Software Stack

### 1. Directory Structure

Create your stack following this structure:

```
your-stack-name/            # Your custom stack directory
├── kustomization.yaml      # Stack entry point
├── repository.yaml         # GitRepository source
├── stack.yaml              # Component/application definitions
├── components/             # Infrastructure components (optional)
│   ├── ingress-nginx/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── source.yaml
│   │   └── release.yaml
│   └── prometheus/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── source.yaml
│       └── release.yaml
└── applications/           # Applications (optional)
    ├── kustomization.yaml
    └── your-app.yaml
```

### 2. Required Files

Your stack must include these three core files:

#### `kustomization.yaml` - Stack Entry Point
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - repository.yaml
  - stack.yaml
```

#### `repository.yaml` - GitRepository Source
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: extension-stack-system
  namespace: flux-system
spec:
  interval: 5m
  url: ${GITOPS_REPO}      # Template variable for repository URL
  ref:
    branch: ${GITOPS_BRANCH} # Template variable for branch
  ignore: |
    # exclude all
    /*
    # include this extension stack
    !/software/stack/extension/your-stack-name/
```

#### `stack.yaml` - Infrastructure and Application Definitions
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: your-infrastructure
  namespace: flux-system
spec:
  interval: 1h
  retryInterval: 1m
  timeout: 10m
  sourceRef:
    kind: GitRepository
    name: extension-stack-system
  path: ./components/your-component
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: your-applications
  namespace: flux-system
spec:
  dependsOn:
    - name: your-infrastructure
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: extension-stack-system
  path: ./applications
  prune: true
  wait: true
```

### 3. Components (Infrastructure)

Create Helm-based infrastructure components in `components/`:

- **Namespace**: Define the component namespace
- **Source**: HelmRepository for the Helm chart
- **Release**: HelmRelease with chart configuration
- **Kustomization**: Ties the files together

### 4. Applications

Create Kubernetes application manifests in `applications/`:

- Standard Kubernetes YAML (Deployments, Services, Ingress, etc.)
- Use `hostk8s.app` labels for proper identification
- Group related resources with Kustomizations

### 5. Template Variables

Use these template variables in your `repository.yaml`:

- `${GITOPS_REPO}` - Repository URL (set by user)
- `${GITOPS_BRANCH}` - Git branch (set by user)

These are automatically substituted when the stack is processed.

## Stack Creation Workflow

1. **Create directory**: `mkdir extension/your-stack-name`
2. **Add core files**: Create `kustomization.yaml`, `repository.yaml`, `stack.yaml`
3. **Add components**: Create infrastructure components as needed
4. **Add applications**: Create application manifests as needed
5. **Version control**: Initialize git repo and commit your stack
6. **Publish**: Push to your Git repository for sharing

## Design Principles

- **Infrastructure as Code**: All components defined in version control
- **Dependency Management**: Use `dependsOn` to control deployment order
- **Reusability**: Create modular components that can be shared
- **GitOps Ready**: Designed for continuous deployment workflows