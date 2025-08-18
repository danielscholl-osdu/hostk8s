# Metrics Server Component

Kubernetes Metrics Server providing container resource usage metrics for monitoring, autoscaling, and resource management. Enables `kubectl top` commands and Horizontal Pod Autoscaler functionality.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|----------|-------------|-----------|----------------|--------------|
| metrics-server | 1 | 50m | 100m | 64Mi | 128Mi |
| **Total Component Resources** | | **50m** | **100m** | **64Mi** | **128Mi** |

## Services & Access

| Service | Endpoint | Port | Purpose |
|---------|----------|------|---------|
| metrics-server | `metrics-server.kube-system.svc.cluster.local` | 443 | Internal metrics API |
| Kubernetes API | `metrics.k8s.io/v1beta1` | - | kubectl top and HPA integration |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Metrics Server Component                   │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │                 │    │                 │                │
│  │  metrics-server │───►│   Metrics API   │                │
│  │  (deployment)   │    │  :10250/metrics │                │
│  │                 │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           ▼                       ▼                        │
│    Collect from kubelets    Serve to kubectl/HPA           │
│                                                             │
│  Deployed to kube-system namespace                          │
└─────────────────────────────────────────────────────────────┘
```

## Integration

Stacks reference this component in their `stack.yaml`:

```yaml
- name: component-metrics-server
  namespace: flux-system
  path: ./software/components/metrics-server
```

Applications can use metrics for autoscaling:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `kube-system` |
| Configuration | Kind-optimized with `--kubelet-insecure-tls` |
| Health Check | HTTP endpoint on metrics-server service |
| Key Features | Real-time CPU/memory metrics, HPA support |

### Basic Operations
```bash
# Check component status
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Test metrics collection
kubectl top nodes
kubectl top pods --all-namespaces

# Verify metrics API availability
kubectl get apiservices v1beta1.metrics.k8s.io
```
