# Metrics Server Component

Kubernetes Metrics Server providing container resource usage metrics for monitoring, autoscaling, and resource management in HostK8s clusters.

## Services

- **Metrics API**: Kubernetes metrics API server for pod and node resource usage
- **Resource Monitoring**: CPU and memory usage collection from kubelets
- **HPA Support**: Horizontal Pod Autoscaler metrics provider

## Architecture

```
┌─────────────────────────────────────────────┐
│             Metrics Server                  │
│                                             │
│  ┌─────────────────────────────────────────┐│
│  │         metrics-server                  ││
│  │       (Helm Chart v3.12.1)             ││
│  │                                         ││
│  │  ┌─────────────────────────────────┐    ││
│  │  │        Metrics API              │    ││
│  │  │    :10250 (secure-port)         │    ││
│  │  │                                 │    ││
│  │  │  ┌─────────────────────────┐    │    ││
│  │  │  │     Kubelet Sources     │    │    ││
│  │  │  │   (All Cluster Nodes)   │    │    ││
│  │  │  └─────────────────────────┘    │    ││
│  │  └─────────────────────────────────┘    ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

## Usage

### Basic Resource Monitoring
```bash
# View pod resource usage
kubectl top pods

# View pod usage in specific namespace
kubectl top pods -n my-namespace

# View node resource usage
kubectl top nodes

# Sort by CPU usage
kubectl top pods --sort-by=cpu

# Sort by memory usage
kubectl top pods --sort-by=memory
```

### Namespace Resource Analysis
```bash
# View all pods with usage across namespaces
kubectl top pods --all-namespaces

# Monitor specific application
kubectl top pods -l app=my-app

# Container-level metrics
kubectl top pods --containers
```

### Integration with Horizontal Pod Autoscaler

```yaml
# Example HPA using metrics-server
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: my-namespace
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
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Programmatic Access

Applications can query metrics via Kubernetes API:

```bash
# Get pod metrics via API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq .

# Get node metrics via API
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .

# Get specific pod metrics
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/default/pods/my-pod" | jq .
```

## Configuration

### Kind-Optimized Settings
- **Insecure TLS**: `--kubelet-insecure-tls` for Kind cluster compatibility
- **Preferred Address Types**: InternalIP, ExternalIP, Hostname order
- **Node Status Port**: Uses kubelet's status port for health checks
- **Metric Resolution**: 15-second collection interval

### Resource Limits
- **CPU Limits**: 100m limit, 50m request
- **Memory Limits**: 128Mi limit, 64Mi request
- **Namespace**: Deployed to `kube-system`

### Security Configuration
```yaml
# Configured for Kind clusters
args:
  - --cert-dir=/tmp
  - --secure-port=10250
  - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
  - --kubelet-use-node-status-port
  - --metric-resolution=15s
  - --kubelet-insecure-tls  # Required for Kind
```

## Storage

- **No Persistent Storage**: Metrics are real-time and not stored
- **Memory Usage**: Metrics stored in memory for API serving
- **Data Retention**: Current metrics only (no historical data)

## Commands

```bash
# Deploy component
kubectl apply -k software/components/metrics-server/

# Check component status
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Check metrics-server logs
kubectl logs -n kube-system deployment/metrics-server

# Verify metrics API is available
kubectl get apiservices | grep metrics

# Test metrics collection
kubectl top nodes
kubectl top pods --all-namespaces

# Check metrics-server service
kubectl get svc -n kube-system metrics-server

# Remove component (be careful - will break HPA)
kubectl delete -k software/components/metrics-server/
```

## Integration Examples

### Development Monitoring
```bash
# Monitor development workload
watch kubectl top pods -n my-dev-namespace

# Check resource usage during load testing
kubectl top pods -l app=load-test --sort-by=cpu
```

### Resource Planning
```bash
# Analyze resource usage patterns
kubectl top pods --all-namespaces --sort-by=memory | head -20

# Monitor cluster capacity
kubectl top nodes
kubectl describe nodes | grep -A5 "Allocated resources"
```

### Autoscaling Validation
```bash
# Create test HPA
kubectl autoscale deployment my-app --cpu-percent=50 --min=1 --max=10

# Monitor HPA behavior
kubectl get hpa my-app -w

# Check HPA status
kubectl describe hpa my-app
```

## Troubleshooting

### Metrics Not Available
```bash
# Check metrics-server pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=metrics-server

# Check metrics-server logs
kubectl logs -n kube-system deployment/metrics-server

# Verify kubelet connectivity
kubectl get nodes -o wide

# Check metrics API registration
kubectl get apiservices v1beta1.metrics.k8s.io
```

### HPA Not Working
```bash
# Check if metrics are available
kubectl top pods -n target-namespace

# Verify HPA can read metrics
kubectl describe hpa my-hpa

# Check HPA controller logs
kubectl logs -n kube-system deployment/hpa-controller
```

### Kind-Specific Issues
```bash
# Verify Kind cluster has metrics-server compatible configuration
kubectl describe node hostk8s-control-plane | grep kubelet

# Check if insecure TLS is properly configured
kubectl logs -n kube-system deployment/metrics-server | grep -i tls

# Test direct kubelet metrics access
kubectl get --raw "/api/v1/nodes/hostk8s-control-plane/proxy/stats/summary"
```

## Monitoring Integration

The metrics-server is essential for:

- **Resource Monitoring**: `kubectl top` commands
- **Horizontal Pod Autoscaling**: CPU/memory-based scaling
- **Vertical Pod Autoscaling**: Resource recommendation (if VPA is installed)
- **Dashboard Integration**: Kubernetes Dashboard resource views
- **Monitoring Systems**: Prometheus can supplement but not replace metrics-server

## Performance Considerations

- **Collection Interval**: 15-second metrics resolution balances accuracy with performance
- **Resource Usage**: Minimal overhead (64Mi memory, 50m CPU requests)
- **Kubelet Load**: Designed to minimize impact on kubelet performance
- **API Response**: Fast response times for `kubectl top` commands

This metrics-server component provides essential resource monitoring capabilities required for effective cluster management and application autoscaling in HostK8s environments.
