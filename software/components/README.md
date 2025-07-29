# Shared Components

This directory contains **shared platform components** that can be optionally included by GitOps stamps. Shared components provide common infrastructure services that multiple stamps can leverage without duplicating configuration.

## Architecture Philosophy

### Shared vs Stamp-Specific Components

- **Shared Components** (`software/components/`): Platform infrastructure that can be reused across stamps
  - Docker registries, monitoring systems, logging aggregation
  - Managed by platform teams, versioned independently
  - Optional inclusion via explicit Kustomize references

- **Stamp-Specific Components** (`software/stamp/{stamp}/components/`): Application-specific infrastructure
  - Databases, ingress controllers, application-specific services
  - Tailored to stamp requirements, managed by application teams
  - Always included when stamp is deployed

### Optional Dependency Pattern

Shared components are **always optional**. Each stamp explicitly chooses which shared components to include:

```yaml
# software/stamp/sample/components/kustomization.yaml
resources:
  # Shared platform components (optional)
  - ../../../components/registry
  - ../../../components/monitoring  # when available

  # Stamp-specific components (always included)
  - ingress-nginx/namespace.yaml
  - database/namespace.yaml
```

## Available Shared Components

### Registry (`software/components/registry/`)

**Purpose**: Local Docker registry for custom image development

**Resources**:
- `registry` namespace with persistent 10Gi storage
- Internal service: `registry.registry.svc.cluster.local:5000`
- External access: NodePort 30500 (http://localhost:30500)
- Registry UI available via `/v2/_catalog` endpoint

**Usage**:
```bash
# Include in stamp
echo "  - ../../../components/registry" >> software/stamp/myapp/components/kustomization.yaml

# Test registry
make registry-test

# Build custom images
make registry-build APP=sample/registry-demo

# Push existing images
make registry-push IMAGE=myapp:latest
```

**Integration**: Kind clusters automatically resolve `localhost:5000` to internal registry service via containerd configuration.

## Creating New Shared Components

### 1. Create Component Directory
```bash
mkdir -p software/components/{component-name}
cd software/components/{component-name}
```

### 2. Define Kubernetes Resources
Create standard Kubernetes manifests:
- `namespace.yaml` - Dedicated namespace with `osdu-ci.component: {name}` label
- `deployment.yaml` - Main service deployment
- `service.yaml` - Service exposure (ClusterIP + NodePort if external access needed)
- `pvc.yaml` - Persistent storage if required
- Additional resources as needed

### 3. Create Kustomization
```yaml
# software/components/{component-name}/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  # Additional resources...
```

### 4. Add Make Targets (Optional)
Add component-specific targets to main Makefile:
```make
##@ {Component} Operations
component-test: ## Test component health
component-info: ## Show component status
```

### 5. Document Usage
Update this README with:
- Component purpose and architecture
- Required resources and access points
- Integration examples
- Make command references

## Component Guidelines

### Naming Conventions
- **Directory**: `software/components/{component-name}/`
- **Namespace**: `{component-name}` (matches directory name)
- **Labels**: `osdu-ci.component: {component-name}`
- **Services**: `{component-name}.{component-name}.svc.cluster.local`

### Resource Management
- **Namespace Isolation**: Each component in dedicated namespace
- **Resource Limits**: Define reasonable CPU/memory limits
- **Persistent Storage**: Use PVCs for data persistence
- **Health Checks**: Include liveness and readiness probes

### External Access Patterns
- **Internal Only**: ClusterIP service for inter-cluster communication
- **Development Access**: NodePort for localhost testing (30500+ range)
- **Production**: LoadBalancer or Ingress for external exposure

### Security Considerations
- **RBAC**: Define minimal required permissions
- **Network Policies**: Restrict inter-namespace communication if needed
- **Secrets Management**: Use Kubernetes secrets, never hardcoded values
- **Image Security**: Use specific image tags, scan for vulnerabilities

## Integration Examples

### Basic Integration
```yaml
# Include registry in your stamp
resources:
  - ../../../components/registry
```

### Conditional Integration
```yaml
# Use environment-specific patches
resources:
  - ../../../components/registry

patchesStrategicMerge:
  - registry-prod-config.yaml  # production-specific settings
```

### Cross-Component Dependencies
```yaml
# Components that depend on other shared components
resources:
  - ../../../components/registry
  - ../../../components/monitoring
  # monitoring may scrape registry metrics
```

## Troubleshooting

### Component Not Starting
1. Check namespace exists: `kubectl get ns {component-name}`
2. Check pod status: `kubectl get pods -n {component-name}`
3. Check logs: `kubectl logs -n {component-name} deployment/{component-name}`
4. Verify resources: `kubectl describe deployment -n {component-name}`

### Access Issues
1. Verify service exists: `kubectl get svc -n {component-name}`
2. Test internal connectivity: `kubectl run test --image=busybox --rm -it -- nslookup {component}.{component}.svc.cluster.local`
3. Check NodePort mapping: `kubectl get svc -n {component-name} -o yaml`

### Stamp Integration Issues
1. Verify Kustomize syntax: `kubectl kustomize software/stamp/{stamp}/components/`
2. Check resource references: ensure paths are correct relative to kustomization.yaml
3. Test stamp deployment: `flux get kustomizations` (if using GitOps)

## Development Workflow

### 1. Local Development
```bash
# Start cluster with stamp that includes component
make up sample

# Test component functionality
make registry-test  # or component-specific test

# Iterate on component changes
kubectl apply -k software/components/{component-name}/
```

### 2. GitOps Integration
```bash
# Component changes sync automatically via Flux
flux get sources git
flux get kustomizations

# Monitor component deployment
kubectl get all -n {component-name}
```

### 3. Multi-Stamp Testing
```bash
# Test component with different stamps
make restart mystamp1
make restart mystamp2  # both using same shared component
```

This shared component architecture enables platform teams to provide common infrastructure while maintaining stamp autonomy and deployment flexibility.
