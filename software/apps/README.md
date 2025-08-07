# HostK8s Applications

Applications for testing and demonstrating various Kubernetes deployment patterns. This directory supports both built-in HostK8s applications and custom external applications through a .gitignore-based extension system.

## How the Extension System Works

- **Everything in this directory is ignored by git by default** (via `.gitignore`)
- **Built-in apps are explicitly included** (`!simple/`, `!complex/`, `!helm-sample/`, etc.)
- **Users can add custom apps** by creating directories here - they won't be tracked by git
- **External apps can be cloned directly** into this directory
- **All apps use the same deployment interface**: `make deploy APP_NAME`

## HostK8s App Contracts

HostK8s supports three deployment patterns, each detected automatically:

### Pattern 1: Helm Chart (Advanced)
```
software/apps/your-app/
├── Chart.yaml          # Helm chart definition (triggers Helm deployment)
├── values.yaml         # Default configuration values
├── values/            # Environment-specific overrides
│   ├── development.yaml
│   └── production.yaml
├── templates/         # Helm templates
│   ├── deployment.yaml
│   ├── service.yaml
│   └── _helpers.tpl
└── README.md          # Documentation
```

### Pattern 2: Kustomization (Intermediate)
```
software/apps/your-app/
├── kustomization.yaml  # Kustomize configuration (preferred for multi-resource apps)
├── deployment.yaml     # Kubernetes resources
├── service.yaml        # Organized as separate files
├── configmap.yaml      # Clean separation of concerns
└── README.md          # Documentation (optional)
```

### Pattern 3: Legacy (Simple)
```
software/apps/your-app/
├── app.yaml           # All-in-one Kubernetes manifests
└── README.md          # Documentation (optional)
```

### The HostK8s Contract Elements

**Required Entry Point:** `kustomization.yaml` (preferred) or `app.yaml` (legacy)

**Required Kustomization Structure:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: your-app       # MUST match directory name
  labels:
    hostk8s.app: your-app

resources:
  - deployment.yaml
  - service.yaml
  # ... list all your YAML files

labels:
  - pairs:
      hostk8s.app: your-app  # THE management contract
```

**Critical Labels:** All Kubernetes resources get labeled with:
```yaml
metadata:
  labels:
    hostk8s.app: your-app  # Must match directory name
```

This label enables:
- `make deploy your-app` to deploy the app
- `make remove your-app` to cleanly remove the app
- `make status` to show the app in cluster health
- `kubectl get all -l hostk8s.app=your-app` for resource management

## Built-in Applications

### simple - Basic Sample
- **Type**: Simple NGINX deployment with ConfigMap content
- **Service**: NodePort (30081)
- **Replicas**: 2 pods
- **Access**: http://localhost:30081 or http://localhost/simple (with ingress)
- **Use Case**: Basic cluster validation and learning
- **Structure**: Kustomization-based (deployment.yaml, service.yaml, etc.)

### complex - Multi-Service Application
- **Type**: Frontend + API services with path-based routing
- **Pattern**: Kustomization
- **Services**: ClusterIP + Ingress routing
- **Replicas**: 4 pods (2 frontend, 2 API)
- **Access**: http://localhost/frontend, http://localhost/api
- **Use Case**: Testing Ingress, multi-service communication
- **Requires**: INGRESS_ENABLED=true
- **Structure**: Kustomization-based with organized service files

### helm-sample - Advanced Voting Application
- **Type**: Multi-service voting system (5 services)
- **Pattern**: Helm Chart
- **Services**: Vote (Flask), Redis, Worker (Java), PostgreSQL, Results (Node.js)
- **Access**: Vote at http://localhost/vote, Results at http://localhost/result
- **Use Case**: Helm templating, values configuration, environment-specific deployment
- **Features**: Values files, templating, configurable scaling and resources
- **Requires**: Ingress enabled for web access
- **Structure**: Full Helm chart with templates and values

## Adding Custom Applications

### Method 1: Clone External App
```bash
cd software/apps/
git clone https://github.com/user/my-k8s-app.git
make deploy my-k8s-app
```

### Method 2: Create New App
```bash
mkdir software/apps/my-app
cd software/apps/my-app

# Create kustomization.yaml
cat > kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: my-app
  labels:
    hostk8s.app: my-app

resources:
  - deployment.yaml
  - service.yaml

labels:
  - pairs:
      hostk8s.app: my-app
EOF

# Add your Kubernetes resources
# ... create deployment.yaml, service.yaml, etc.

# Deploy
make deploy my-app
```

### Method 3: Legacy Single-File App
```bash
mkdir software/apps/my-legacy-app
# Copy your all-in-one Kubernetes manifests to app.yaml
cp my-manifests.yaml software/apps/my-legacy-app/app.yaml
make deploy my-legacy-app
```

## Best Practices

### Resource Management
- Set appropriate resource requests and limits
- Use meaningful names and labels
- Include health checks when applicable
- Organize complex apps using the Kustomization pattern

### Networking
- For web apps, use Ingress with path-based routing (`/your-app`)
- For internal services, use ClusterIP
- For external access, use NodePort or LoadBalancer
- Avoid port conflicts - check existing NodePorts first

### Configuration
- Use ConfigMaps for configuration data
- Use Secrets for sensitive data
- Mount volumes appropriately
- Follow the HostK8s labeling contract

### Documentation
- Include a README.md explaining what your app does
- Document access methods and configuration options
- Provide deployment and usage examples
- Note any special requirements (INGRESS_ENABLED, etc.)

## Deployment Commands

```bash
# Deploy any app
make deploy APP_NAME

# Check status
make status                                    # Shows all apps in cluster health
kubectl get all -l hostk8s.app=APP_NAME      # Shows specific app resources

# Remove app
make remove APP_NAME

# List available apps
make deploy  # Shows available apps if no name provided
```

## Troubleshooting

### App Not Showing in Status
- Verify `hostk8s.app: YOUR_APP_NAME` label is on all resources
- Ensure label value matches directory name exactly
- Check deployment succeeded: `kubectl get all -l hostk8s.app=YOUR_APP_NAME`

### Deployment Fails
- **Kustomization apps**: Validate with `kubectl apply --dry-run=client -k .`
- **Legacy apps**: Validate with `kubectl apply --dry-run=client -f app.yaml`
- Check resource names don't conflict with existing resources
- Verify NodePort isn't already allocated
- Ensure required infrastructure is enabled (ingress, metallb)

### Access Issues
- **Ingress**: Ensure `INGRESS_ENABLED=true` and path is unique
- **NodePort**: Check port isn't already in use (`kubectl get svc --all-namespaces`)
- **LoadBalancer**: Requires `METALLB_ENABLED=true` in Kind clusters
- **ClusterIP**: Access only works from within cluster

## Directory Structure After Extensions

Your `software/apps/` directory might look like:

```
software/apps/
├── .gitignore                    # Excludes everything except built-ins
├── README.md                     # This file
├── simple/                       # Built-in app (tracked)
├── complex/                      # Built-in app (tracked)
├── helm-sample/                  # Built-in app (tracked)
├── my-custom-app/                # Your app (ignored by git)
├── team-voting-system/           # External clone (ignored by git)
└── prototype-microservice/       # Your experiment (ignored by git)
```

This approach provides clean separation between HostK8s built-in applications and your custom extensions, while maintaining the same deployment interface for everything.
