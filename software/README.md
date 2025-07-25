# OSDU-CI Software Examples

This directory contains practical examples for using your OSDU-CI Kind development cluster.

## Directory Structure

```
software/
├── README.md           # This file
├── apps/               # Sample applications with structured deployment
│   ├── app1/           # Basic sample app (NodePort)
│   ├── app2/           # Advanced sample app (MetalLB + Ingress)
│   └── README.md       # App deployment documentation
├── stamp/              # Flux GitOps examples
│   ├── sources/        # Git and Helm repositories
│   ├── apps/           # Application deployments
│   ├── clusters/       # Cluster-specific configurations
│   └── README.md       # GitOps documentation
└── configs/            # Additional configurations
```

## Quick Start

### 1. Deploy Sample Applications

```bash
# Deploy basic app (NodePort)
make deploy app1

# Deploy advanced app (requires MetalLB + Ingress)
METALLB_ENABLED=true INGRESS_ENABLED=true make up
make deploy app2

# Access via browser
open http://localhost:8080
```

### 2. Multi-Service Architecture

```bash
# Deploy 3-tier application
make deploy app3

# Check services
kubectl get pods,svc -l tier=frontend
kubectl get pods,svc -l tier=api  
kubectl get pods,svc -l tier=database
```

### 3. GitOps with Flux

```bash
# Enable Flux
FLUX_ENABLED=true make up

# Check Flux status
export KUBECONFIG=$(pwd)/data/kubeconfig/config
flux get all

# Apply GitOps examples
kubectl apply -f software/stamp/sources/
kubectl apply -f software/stamp/apps/
```

## Development Patterns

### Application Development

1. **Start with app1** - Basic deployment patterns
2. **Progress to app2** - Advanced networking with MetalLB/Ingress
3. **Explore app3** - Multi-service microservices communication
4. **Implement GitOps** - Declarative deployments with Flux

### Testing Scenarios

```bash
# Test different access methods
curl http://localhost:8080                    # NodePort
curl http://172.18.255.200                    # LoadBalancer (if MetalLB enabled)
curl -H "Host: myapp.local" http://localhost:8080  # Ingress

# Test scaling
kubectl scale deployment sample-app --replicas=5

# Test rolling updates  
kubectl set image deployment/sample-app nginx=mcr.microsoft.com/azurelinux/base/nginx

# Test resource usage
kubectl top pods
```

### Network Testing

```bash
# DNS resolution test
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Service connectivity test
kubectl exec -it deployment/sample-app -- wget -qO- http://sample-app

# Ingress test
kubectl exec -it deployment/sample-app -- wget -qO- http://ingress-nginx-controller.ingress-nginx
```

## Advanced Examples

### Custom Applications

Create new applications by following the app structure:

```bash
# Create new app
mkdir software/apps/app3
cp software/apps/app1/app.yaml software/apps/app3/
# Edit app3/app.yaml with your application
make deploy app3
```

### GitOps Workflows

1. Create a Git repository with your application manifests
2. Configure GitRepository and Kustomization in `software/stamp/`
3. Let Flux automatically deploy and sync your applications

### Multi-Environment Setup

Use different Kind configurations for different environments:

```bash
# Development cluster
KIND_CONFIG=minimal make up

# Staging-like cluster  
KIND_CONFIG=default METALLB_ENABLED=true INGRESS_ENABLED=true make up

# Full-featured cluster
KIND_CONFIG=default METALLB_ENABLED=true INGRESS_ENABLED=true FLUX_ENABLED=true make up
```

## Troubleshooting

### Common Issues

```bash
# Check cluster status
make status

# View recent events
make logs

# Debug specific app
kubectl describe deployment sample-app
kubectl logs -l app=sample-app --tail=50
```

### Resource Cleanup

```bash
# Remove specific app
kubectl delete -f software/apps/app1/app.yaml

# Remove all apps
kubectl delete all --all -n default

# Full cluster reset
make clean && make up
```

## Best Practices

1. **Use resource requests/limits** - Prevent resource starvation
2. **Add health checks** - Implement readiness/liveness probes  
3. **Label everything** - Use consistent labeling strategy
4. **Test all access methods** - NodePort, LoadBalancer, Ingress
5. **Use namespaces** - Isolate different applications
6. **Implement GitOps** - Declarative, version-controlled deployments

## Resources

- [Apps Documentation](apps/README.md) - Structured app deployment
- [Multi-Service Documentation](apps/app3/README.md) - Microservices patterns
- [GitOps Documentation](stamp/README.md) - Flux GitOps workflows
- [Main README](../README.md) - OSDU-CI overview
- [Architecture Documentation](../docs/architecture.md) - System design