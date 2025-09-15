# Istio Service Mesh Component

A lightweight Istio implementation using **Ambient mode** and **Gateway API** for HostK8s, providing modern ingress and service mesh capabilities with minimal resource overhead.

## Architecture

This component implements Istio with three key design decisions optimized for local development:

1. **Ambient Mode** - Ultra-lightweight L4 service mesh (50MB overhead vs 1GB+ for sidecars)
2. **Gateway API** - Kubernetes-native ingress using standard resources
3. **Automated Deployment** - Gateway resources auto-provision infrastructure

### Components

```
┌─────────────────────────────────────────────────────────┐
│                    Istio Component                       │
├───────────────────┬──────────────┬────────────────────┤
│     Base          │   Ambient     │      Gateway        │
├───────────────────┼──────────────┼────────────────────┤
│ • Gateway API CRDs│ • ZTunnel     │ • GatewayClass     │
│ • Istio Base      │ • Waypoint    │ • Gateway (auto)   │
│ • Istiod          │   Class       │ • HTTPRoutes       │
│                   │               │ • TLS Certs        │
└───────────────────┴──────────────┴────────────────────┘
```

## Features

### Gateway API Ingress
- **Automated Infrastructure**: Gateway resources automatically deploy pods/services
- **Standard Resources**: Uses HTTPRoute instead of proprietary Ingress
- **NodePort Mapping**: Works with Kind's port forwarding (8080/8443)
- **TLS Support**: Automatic certificate generation via cert-manager

### Ambient Mode Service Mesh
- **Zero Restarts**: Enable mTLS without restarting pods
- **Minimal Overhead**: 50MB for entire cluster (ztunnel)
- **Progressive L7**: Add waypoint proxies only where needed
- **Instant Security**: Label namespace for immediate mTLS

## Prerequisites

- HostK8s cluster running (`make start`)
- cert-manager component installed (for TLS certificates)

## Installation

### Option 1: Include in Stack

Add to your stack's kustomization:

```yaml
resources:
  - ../../components/istio
```

### Option 2: Direct Deployment

```bash
kubectl apply -k software/components/istio
```

## Usage

### 1. Enable Ambient Mode for a Namespace

Add mTLS and L4 features instantly (no pod restarts!):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    istio.io/dataplane-mode: ambient  # That's it!
```

Or via kubectl:
```bash
kubectl label namespace my-app istio.io/dataplane-mode=ambient
```

### 2. Expose Services via Gateway API

Create an HTTPRoute for your service:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: my-app
spec:
  parentRefs:
  - name: hostk8s-gateway
    namespace: istio-system
  hostnames:
  - "localhost"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /app
    backendRefs:
    - name: my-service
      port: 8080
```

Access at: `http://localhost:8080/app`

### 3. Add L7 Features (Optional)

Deploy a waypoint proxy for HTTP-level features:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-app-waypoint
  namespace: my-app
  labels:
    istio.io/waypoint-for: namespace
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

Then use it:
```bash
kubectl label namespace my-app istio.io/use-waypoint=my-app-waypoint
```

## Configuration

### Environment Variables

Configure via `.env` or environment:

```bash
# Component enablement
ISTIO_ENABLED=true                    # Enable Istio component

# Gateway configuration
ISTIO_GATEWAY_REPLICAS=1             # Number of gateway replicas
ISTIO_GATEWAY_CPU=50m                # Gateway CPU request
ISTIO_GATEWAY_MEMORY=64Mi            # Gateway memory request

# Ambient mode
ISTIO_AMBIENT_ENABLED=true           # Enable Ambient mode
ISTIO_ZTUNNEL_LOG_LEVEL=info        # ZTunnel log level (info/debug/trace)

# Optional features
ISTIO_TELEMETRY_ENABLED=false       # Enable metrics/tracing
```

### Customizing Gateway

Modify the ConfigMap in `gateway/gateway-config.yaml`:

```yaml
data:
  service: |
    type: LoadBalancer  # If using MetalLB
    # or
    type: NodePort      # Default for Kind
```

## Migration from NGINX Ingress

### Parallel Operation

Both NGINX and Istio can run simultaneously:

- **NGINX**: Continues on ports 80/443 (mapped to 8080/8443)
- **Istio**: Same ports via Gateway API
- **Apps**: Can use either Ingress or HTTPRoute

### Migration Path

1. **Existing Apps**: Keep using NGINX Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: nginx  # Still works
```

2. **New Apps**: Use Gateway API HTTPRoute
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  parentRefs:
  - name: hostk8s-gateway
```

3. **Enable Ambient**: Add mTLS with one label
```bash
kubectl label ns my-app istio.io/dataplane-mode=ambient
```

## Resource Usage

### Memory Comparison (10 services)

| Mode | Components | Memory | vs Sidecar |
|------|------------|--------|------------|
| **NGINX Only** | Controller | ~100MB | N/A |
| **Istio Sidecar** | istiod + 10 sidecars + gateway | ~1.3GB | Baseline |
| **Istio Ambient** | istiod + ztunnel + gateway | ~250MB | -81% |
| **Ambient + L7** | + 2 waypoints | ~450MB | -65% |

### CPU Usage

- **Istiod**: 100m request
- **ZTunnel**: 50m request
- **Gateway**: 50m request
- **Waypoint**: 50m request (when deployed)

## Troubleshooting

### Check Component Status

```bash
# Verify all components are running
kubectl get pods -n istio-system

# Expected output:
# NAME                                  READY   STATUS
# istiod-xxx                           1/1     Running
# ztunnel-xxx                          1/1     Running
# hostk8s-gateway-istio-xxx            1/1     Running
```

### Verify Ambient Mode

```bash
# Check namespace labels
kubectl get namespace -L istio.io/dataplane-mode

# Check ztunnel logs
kubectl logs -n istio-system -l app=ztunnel

# Verify mTLS is working
kubectl exec -n my-app deployment/my-app -c istio-proxy -- \
  curl -s http://another-service:8080/
```

### Gateway Troubleshooting

```bash
# Check Gateway status
kubectl get gateway -n istio-system hostk8s-gateway

# Check auto-created resources
kubectl get deployment,service -n istio-system | grep hostk8s-gateway

# View HTTPRoutes
kubectl get httproute -A

# Test routing
curl -v http://localhost:8080/healthz
```

### Common Issues

#### Gateway Not Creating Resources

Check GatewayClass exists:
```bash
kubectl get gatewayclass istio
```

#### HTTPRoute Not Working

Verify parent reference:
```bash
kubectl describe httproute my-app -n my-namespace
```

#### Ambient Mode Not Working

Check ztunnel is running:
```bash
kubectl get daemonset -n istio-system ztunnel
```

#### High Memory Usage

You might be using sidecar mode by mistake:
```bash
# Check for sidecars
kubectl get pods -A -o json | jq '.items[].spec.containers[].name' | grep istio-proxy

# Remove sidecar injection
kubectl label namespace my-app istio-injection-
```

## Advanced Features

### Traffic Management

```yaml
# Canary deployment with traffic splitting
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary
spec:
  rules:
  - backendRefs:
    - name: app-v1
      port: 8080
      weight: 90  # 90% traffic
    - name: app-v2
      port: 8080
      weight: 10  # 10% traffic
```

### Request/Response Modification

```yaml
# Add headers, rewrite paths
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: modify
spec:
  rules:
  - filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: X-Custom-Header
          value: "true"
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /v2
```

### Authorization Policies

```yaml
# L4 authorization (works with Ambient)
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-frontend
  namespace: backend
spec:
  rules:
  - from:
    - source:
        namespaces: ["frontend"]
    to:
    - operation:
        ports: ["8080"]
```

## Uninstallation

Remove the component:

```bash
# Remove from Flux
kubectl delete kustomization -n flux-system component-istio-gateway
kubectl delete kustomization -n flux-system component-istio-ambient
kubectl delete kustomization -n flux-system component-istio-base

# Or directly
kubectl delete -k software/components/istio
```

## Architecture Decision Records

This component implements decisions from:
- Gateway API for native Kubernetes ingress
- Ambient mode for resource-efficient service mesh
- Automated gateway deployment for simplified operations

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Istio logs: `kubectl logs -n istio-system -l app=istiod`
3. Consult [Istio documentation](https://istio.io/latest/docs/)
4. Open an issue in the HostK8s repository
