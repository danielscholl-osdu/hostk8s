# Istio Bookinfo Demo Stack

A comprehensive demonstration of Istio service mesh capabilities using the classic Bookinfo application, showcasing Gateway API, Ambient mode, and advanced traffic management features.

## Overview

The Bookinfo application is Istio's canonical example application, consisting of four separate microservices that work together to display information about a book, similar to a single catalog entry of an online book store.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │
│  productpage │────▶│   reviews    │────▶│   ratings    │
│   (Python)   │     │    (Java)    │     │   (Node.js)  │
│              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
        │                    │
        │            ┌───────┴────────┐
        │            │ • v1: No stars │
        ▼            │ • v2: Black ★  │
┌──────────────┐     │ • v3: Red ★    │
│              │     └────────────────┘
│   details    │
│    (Ruby)    │
│              │
└──────────────┘
```

## Features

### Service Mesh Capabilities

- **Ambient Mode**: Instant mTLS without sidecars (50MB overhead vs 400MB+)
- **Gateway API**: Modern Kubernetes-native ingress using HTTPRoute
- **Traffic Management**: Canary deployments with weighted routing
- **Observability**: Distributed tracing and metrics (when enabled)
- **Resilience**: Circuit breaking and retry policies (with waypoint)

### Components Included

1. **cert-manager**: Provides TLS certificates for Gateway
2. **Istio**: Service mesh with Ambient mode and Gateway API
3. **Bookinfo**: Four microservices demonstrating mesh features

## Prerequisites

- HostK8s cluster running (`make start`)
- Flux installed (`make up` will install if needed)

## Installation

### Quick Start

```bash
# Deploy the entire stack
make up book-app

# Wait for all components to be ready (2-3 minutes)
kubectl get pods -n bookinfo

# Access the application
curl http://localhost:8080/productpage
# Or open in browser: http://localhost:8080/productpage
```

### Manual Deployment

```bash
# Apply the stack
kubectl apply -k software/stacks/book-app

# Monitor deployment
kubectl get kustomization -n flux-system | grep book-app
```

## Accessing the Application

### Primary Endpoints

- **Product Page**: http://localhost:8080/productpage
- **Health Check**: http://localhost:8080/health
- **Direct API Access**:
  - Details: http://localhost:8080/details/0
  - Reviews: http://localhost:8080/reviews/0
  - Ratings: http://localhost:8080/ratings/0

### Traffic Distribution

By default, the reviews service uses weighted routing:
- **60%** → v1 (no stars)
- **20%** → v2 (black stars)
- **20%** → v3 (red stars)

Refresh the product page multiple times to see different versions!

## Demonstrating Istio Features

### 1. Verify Ambient Mode mTLS

```bash
# Check that namespace has Ambient mode enabled
kubectl get namespace bookinfo -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
# Output: ambient

# Verify ztunnel is handling traffic
kubectl logs -n istio-system -l app=ztunnel | grep bookinfo

# Check mTLS between services
kubectl exec -n bookinfo deployment/productpage-v1 -- \
  curl -s http://details:9080/details/0 | jq .
```

### 2. Traffic Management

Modify traffic weights by editing the HTTPRoute:

```bash
kubectl edit httproute bookinfo-reviews -n bookinfo
# Change the weight values and save
```

### 3. Enable L7 Features (Optional)

Deploy waypoint proxy for advanced features:

```bash
# Apply waypoint configuration
kubectl apply -f software/stacks/book-app/manifests/waypoint.yaml.optional

# Verify waypoint is running
kubectl get gateway bookinfo-waypoint -n bookinfo

# Test circuit breaker (ratings service)
for i in {1..20}; do
  curl -s http://localhost:8080/productpage | grep -o "Ratings service.*" &
done
```

### 4. Fault Injection Testing

With waypoint enabled, test resilience:

```bash
# The waypoint.yaml.optional includes fault injection
# 10% of ratings requests will have 5s delay
# 5% of ratings requests will return 500 error

# Watch the behavior
while true; do
  curl -s http://localhost:8080/productpage | grep -E "(Ratings|Error)"
  sleep 1
done
```

## Resource Usage

### Without Waypoint (L4 only)
- **istiod**: ~150MB
- **ztunnel**: ~50MB
- **gateway**: ~64MB
- **bookinfo services**: ~200MB total
- **Total**: ~464MB

### With Waypoint (L4 + L7)
- Additional waypoint proxy: ~128MB
- **Total**: ~592MB

Compare to sidecar mode: Would use ~1.2GB+ (300MB per service with sidecars)

## Customization

### Modify Service Resources

Edit `manifests/release.yaml` to adjust resource limits:

```yaml
values:
  productpage:
    resources:
      requests:
        cpu: 20m
        memory: 64Mi
```

### Change Traffic Routing

Edit `manifests/httproutes.yaml` to modify routing rules:

```yaml
backendRefs:
- name: reviews-v1
  port: 9080
  weight: 100  # Send all traffic to v1
```

### Add Custom Policies

Create additional policies in `manifests/` directory:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: productpage-authz
  namespace: bookinfo
spec:
  selector:
    matchLabels:
      app: productpage
  rules:
  - to:
    - operation:
        methods: ["GET"]
```

## Troubleshooting

### Services Not Accessible

```bash
# Check if all pods are running
kubectl get pods -n bookinfo

# Verify HTTPRoutes are configured
kubectl get httproute -n bookinfo

# Check Gateway is accepting traffic
kubectl get gateway hostk8s-gateway -n istio-system
```

### Ambient Mode Not Working

```bash
# Verify ztunnel is running
kubectl get pods -n istio-system -l app=ztunnel

# Check namespace label
kubectl get namespace bookinfo --show-labels

# View ztunnel logs
kubectl logs -n istio-system -l app=ztunnel --tail=100
```

### Reviews Service Shows Only One Version

```bash
# Check if all review versions are running
kubectl get pods -n bookinfo | grep reviews

# Verify HTTPRoute has correct weights
kubectl get httproute bookinfo-reviews -n bookinfo -o yaml
```

### High Memory Usage

```bash
# Check if waypoint is deployed (optional component)
kubectl get gateway -n bookinfo

# Remove waypoint if not needed
kubectl delete gateway bookinfo-waypoint -n bookinfo
```

## Cleanup

### Remove the Stack

```bash
# Using make
make down book-app

# Or manually
kubectl delete kustomization app-bookinfo -n flux-system
kubectl delete kustomization component-istio -n flux-system
kubectl delete kustomization component-certs -n flux-system
kubectl delete namespace bookinfo
```

### Partial Cleanup

```bash
# Remove just the application, keep Istio
kubectl delete kustomization app-bookinfo -n flux-system
kubectl delete namespace bookinfo

# Remove waypoint only
kubectl delete -f software/stacks/book-app/manifests/waypoint.yaml.optional
```

## Architecture Decisions

### Why Ambient Mode?

- **Resource Efficiency**: 81% less memory than sidecar mode
- **No Restarts**: Configuration changes don't require pod restarts
- **Instant mTLS**: Just label the namespace
- **Progressive L7**: Add waypoints only where needed

### Why Gateway API?

- **Kubernetes Native**: Standard API, not vendor-specific
- **Future Proof**: All ingress controllers moving to Gateway API
- **Powerful Routing**: Advanced traffic management built-in
- **Auto-provisioning**: Gateway resources create infrastructure automatically

### Why Helm Chart?

- **Maintainability**: Community-maintained chart stays updated
- **Configurability**: Easy to adjust resources and features
- **Consistency**: Standardized deployment across environments

## Links and References

- [Istio Bookinfo Documentation](https://istio.io/latest/docs/examples/bookinfo/)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Istio Ambient Mode](https://istio.io/latest/docs/ambient/)
- [HostK8s Istio Component](../../components/istio/README.md)

## Support

For issues specific to this stack:
1. Check the troubleshooting section above
2. Review component logs: `kubectl logs -n bookinfo -l app=productpage`
3. Check Istio status: `kubectl get pods -n istio-system`
4. Open an issue in the HostK8s repository
