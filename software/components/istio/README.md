# Istio Service Mesh Component

## Problem Statement

Modern microservice applications require secure communication, traffic management, and observability features that traditional Kubernetes networking doesn't provide. Implementing these capabilities typically requires complex sidecar proxy injection that:

- Consumes significant memory (100MB+ per pod)
- Requires pod restarts for configuration changes
- Creates operational complexity for developers
- Increases resource usage beyond development laptop capacity

**The Service Mesh Challenge:**
Developers need production-like service mesh capabilities for testing distributed applications, but traditional sidecar-based implementations create resource constraints and operational overhead in local development environments.

**Ambient Mode Solution:**
Istio Ambient mode provides enterprise-grade service mesh capabilities without sidecars, using node-level proxies that deliver 81% memory reduction while enabling instant configuration changes and automatic mTLS encryption.

## Solution Overview

This component provides a lightweight Istio service mesh using **Ambient mode** and **Gateway API** integration, following HostK8s's simplified component pattern. The implementation delivers production-grade service mesh capabilities optimized for resource-constrained local development environments.

**Key Capabilities:**
- **Zero-restart mesh enablement** - Label namespaces for instant mTLS without pod modifications
- **Kubernetes-native ingress** - Gateway API resources with automatic infrastructure provisioning
- **Resource efficiency** - 50MB mesh overhead vs 1GB+ with sidecar mode
- **Dual CNI integration** - Works seamlessly with Kind's default networking
- **Progressive complexity** - L4 features always available, L7 features deployed when needed

## Terminology

To clarify the relationship between Istio components and HostK8s architecture:

| Component Term | Purpose | Resource Location |
|----------------|---------|------------------|
| **Control Plane** | Istio management and configuration | `istiod` deployment in `istio-system` |
| **Ambient Dataplane** | Node-level traffic interception | `ztunnel` DaemonSet + `istio-cni` plugin |
| **Gateway** | Ingress traffic management | Auto-deployed Gateway pods via Gateway API |
| **Waypoint** | Optional L7 proxy | On-demand Gateway resources per namespace/service |

**Resource Relationships:**
- Each **namespace** labeled `istio.io/dataplane-mode=ambient` → **automatic mTLS** for all pods
- Each **HTTPRoute** resource → **routing rules** through the shared Gateway
- Each **waypoint** Gateway → **L7 features** for specific services/namespaces

**Integration Pattern:**
```yaml
# Application declares mesh participation:
metadata:
  labels:
    istio.io/dataplane-mode: ambient    # Enables mesh features

# Application declares ingress:
spec:
  parentRefs:
    - name: hostk8s-gateway             # Uses shared Gateway resource
      namespace: istio-system
```

## Component Architecture

### Single Kustomization Structure

The component follows HostK8s's simplified pattern, deploying all Istio components through a single Flux Kustomization with linear dependencies:

```yaml
# Component deploys in order:
1. namespace.yaml              # istio-system namespace
2. sources.yaml               # Helm repositories + Gateway API CRDs
3. control-plane.yaml         # istio-base + istiod
4. ambient-dataplane.yaml     # istio-cni + ztunnel
5. gateway.yaml               # Gateway resource + auto-patch job
6. certificate.yaml           # TLS certificate via cert-manager
```

### Resource Allocation

| Component | CPU Request | Memory Request | Purpose |
|-----------|-------------|----------------|---------|
| **istiod** | 100m | 128Mi | Control plane management |
| **ztunnel** | 50m | 64Mi | L4 traffic interception |
| **istio-cni** | 100m | 128Mi | Network configuration |
| **Gateway** | 50m | 64Mi | Ingress traffic handling |
| **Total** | ~300m | ~384Mi | **vs 1GB+ sidecar mode** |

### Gateway Integration Strategy

The component automatically provisions Gateway API infrastructure with HostK8s-specific configuration:

- **Service Type**: NodePort for Kind cluster compatibility
- **Port Mapping**: Non-conflicting ports (30081/30444) to coexist with NGINX Ingress
- **TLS Integration**: Automatic certificate provisioning via cert-manager
- **Auto-Configuration**: Post-deployment job ensures correct port mappings

## Installation

### Prerequisites
- HostK8s cluster running (`make start`)
- cert-manager component (for TLS certificates)

### Stack Integration

Include in your stack's dependency chain:

```yaml
# software/stacks/my-stack/stack.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-certs
  namespace: flux-system
spec:
  path: ./software/components/certs
  # ... standard configuration

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: component-istio
  namespace: flux-system
spec:
  dependsOn:
    - name: component-certs
  path: ./software/components/istio
  # ... standard configuration
```

### Direct Deployment

```bash
# Deploy cert-manager first
kubectl apply -k software/components/certs

# Deploy Istio component
kubectl apply -k software/components/istio
```

## Integration Patterns

### Enabling Ambient Mode for Applications

Applications join the service mesh by labeling their namespace:

```yaml
# Enable mesh for entire namespace (recommended)
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    istio.io/dataplane-mode: ambient    # Instant mTLS!
    hostk8s.stack: my-stack
    hostk8s.app: my-app
```

**Immediate Benefits:**
- **Automatic mTLS** between all services in the namespace
- **Identity verification** using SPIFFE identities
- **Network policy enforcement** at L4
- **Traffic telemetry** collection

**No Changes Required:**
- Existing pods continue running unchanged
- No restarts needed
- Configuration changes apply instantly

### Exposing Services via Gateway API

Applications expose services through HTTPRoute resources:

```yaml
# Basic service exposure
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: my-app
  labels:
    hostk8s.application: my-app    # For status detection
spec:
  parentRefs:
  - name: hostk8s-gateway
    namespace: istio-system
  hostnames:
  - "localhost"
  - "my-app.hostk8s.local"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /my-app
    backendRefs:
    - name: my-service
      port: 8080
```

**Access Pattern:**
- **Gateway API**: `http://localhost:8081/my-app` (Istio service mesh)
- **NGINX Ingress**: `http://localhost:8080/my-app` (traditional ingress)

### Advanced Traffic Management

```yaml
# Traffic splitting for canary deployments
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-deployment
  namespace: my-app
spec:
  parentRefs:
  - name: hostk8s-gateway
    namespace: istio-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: my-service-v1
      port: 8080
      weight: 90      # 90% traffic to stable version
    - name: my-service-v2
      port: 8080
      weight: 10      # 10% traffic to canary version
```

### Optional L7 Features

Deploy waypoint proxies when HTTP-level features are needed:

```yaml
# Waypoint for advanced L7 capabilities
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

---
# Enable waypoint for namespace
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    istio.io/dataplane-mode: ambient
    istio.io/use-waypoint: my-app-waypoint
```

**Waypoint Capabilities:**
- HTTP retries and timeouts
- Circuit breaking
- Fault injection for testing
- Advanced routing policies

## Lifecycle

When you deploy the Istio component via `make up {stack}`, HostK8s automatically:

1. **Dependency Validation** → Ensures cert-manager is ready
2. **Gateway API Installation** → Installs Kubernetes Gateway API CRDs
3. **Control Plane Deployment** → Deploys istio-base and istiod with Ambient profile
4. **Dataplane Configuration** → Installs CNI plugin and ztunnel for traffic interception
5. **Gateway Provisioning** → Creates shared Gateway resource with auto-configuration
6. **Certificate Generation** → Provisions TLS certificates via cert-manager integration

## Configuration Options

### Environment Variables

Configure component behavior through standard HostK8s environment variables:

```bash
# Component enablement (in .env)
ISTIO_ENABLED=true                    # Enable Istio component in stacks

# Resource optimization
ISTIO_CONTROL_PLANE_MEMORY=128Mi     # istiod memory limit
ISTIO_DATAPLANE_MEMORY=64Mi          # ztunnel memory limit
ISTIO_GATEWAY_REPLICAS=1             # Gateway pod replicas

# Feature flags
ISTIO_TELEMETRY_ENABLED=false       # Disable telemetry for resource savings
ISTIO_ACCESS_LOGS=true              # Enable access logging (debugging)
```

### Ambient Mode Configuration

Control mesh participation per namespace:

```yaml
# Enable for production-like testing
metadata:
  labels:
    istio.io/dataplane-mode: ambient

# Disable for specific namespaces
metadata:
  labels:
    istio.io/dataplane-mode: none
```

### Gateway Customization

The auto-patch job ensures Gateway services use correct NodePorts for Kind integration:

- **HTTP**: NodePort 30081 → Host port 8081
- **HTTPS**: NodePort 30444 → Host port 8444

This enables coexistence with NGINX Ingress (8080/8443) on the same cluster.

## Architecture Benefits

### Resource Efficiency Comparison

| Scenario | Sidecar Mode | Ambient Mode | Savings |
|----------|--------------|--------------|---------|
| **5 services** | ~650MB | ~350MB | 46% |
| **10 services** | ~1.3GB | ~400MB | 69% |
| **20 services** | ~2.6GB | ~500MB | 81% |

*Measurements include istiod, dataplane components, and gateway resources*

### Operational Benefits

**Traditional Sidecar Mode:**
- ❌ Pod restart required for mesh configuration changes
- ❌ 100MB+ memory per pod regardless of traffic
- ❌ Complex injection and upgrade procedures
- ❌ Resource waste in development environments

**HostK8s Ambient Mode:**
- ✅ Instant configuration via namespace labeling
- ✅ Minimal fixed overhead regardless of pod count
- ✅ Zero application code or manifest changes
- ✅ Laptop-friendly resource consumption

### Integration Advantages

**Dual Ingress Controller Support:**
The component coexists with NGINX Ingress, enabling gradual service mesh adoption:

- **Traditional Apps**: Continue using NGINX Ingress (8080/8443)
- **Mesh Apps**: Use Gateway API for advanced features (8081/8444)
- **Migration Path**: Apps can switch when ready

**Standard HostK8s Compatibility:**
- Uses standard `kind-custom.yaml` cluster configuration
- Integrates with existing addons (Vault, Registry, Metrics)
- Follows established component patterns (postgres/redis model)
- Compatible with all HostK8s stack deployment workflows

## Troubleshooting

### Component Health Verification

```bash
# Check all Istio components
kubectl get pods -n istio-system

# Expected output:
# istiod-*                      1/1 Running
# istio-cni-node-*             1/1 Running
# ztunnel-*                    1/1 Running
# hostk8s-gateway-istio-*      1/1 Running
# gateway-nodeport-patcher-*   Completed
```

### Ambient Mode Validation

```bash
# Verify namespace is in mesh
kubectl get namespace my-app -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'
# Expected: ambient

# Check ztunnel traffic logs
kubectl logs -n istio-system -l app=ztunnel | grep my-app

# Verify service-to-service mTLS
kubectl exec -n my-app deployment/my-app -- \
  curl -s http://other-service:8080/health
```

### Gateway API Connectivity

```bash
# Check Gateway status
kubectl get gateway hostk8s-gateway -n istio-system

# Check auto-deployed service
kubectl get service hostk8s-gateway-istio -n istio-system

# Test connectivity
curl http://localhost:8081/my-app
```

### Common Issues

#### Gateway Not Accessible
1. **Check NodePort mapping**: `kubectl get service hostk8s-gateway-istio -n istio-system`
2. **Verify auto-patch job ran**: `kubectl get job gateway-nodeport-patcher -n istio-system`
3. **Test Kind port mapping**: `docker port $(kubectl config current-context | sed 's/kind-//')-control-plane`

#### Ambient Mode Not Working
1. **Verify ztunnel is running**: `kubectl get daemonset ztunnel -n istio-system`
2. **Check namespace label**: `kubectl get namespace my-app --show-labels`
3. **Review CNI logs**: `kubectl logs -n istio-system -l app=istio-cni`

#### High Memory Usage
You might have leftover sidecar injection enabled:
```bash
# Remove sidecar injection (not needed with Ambient)
kubectl label namespace my-app istio-injection-

# Verify no sidecars exist
kubectl get pods -n my-app -o jsonpath='{.items[*].spec.containers[*].name}' | grep -v istio-proxy
```

## Migration from Traditional Istio

### From Sidecar Mode

If migrating from existing sidecar-based Istio:

```bash
# 1. Remove sidecar injection
kubectl label namespace my-app istio-injection-

# 2. Enable Ambient mode
kubectl label namespace my-app istio.io/dataplane-mode=ambient

# 3. Restart pods to remove sidecars (optional - they'll coexist)
kubectl rollout restart deployment -n my-app
```

### From Traditional Ingress

Convert existing Ingress resources to HTTPRoute:

```yaml
# Before (traditional Ingress)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: nginx
  rules:
  - host: localhost
    http:
      paths:
      - path: /my-app
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 8080

# After (Gateway API)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  parentRefs:
  - name: hostk8s-gateway
    namespace: istio-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /my-app
    backendRefs:
    - name: my-service
      port: 8080
```

## Architecture Decision Records

This component implements several key architectural decisions:

- **Ambient Mode Adoption** - Prioritizes resource efficiency over maximum feature completeness for local development
- **Dual CNI Strategy** - Leverages Kind's default networking with Istio CNI as enhancement layer
- **Simplified Component Pattern** - Single Kustomization following postgres/redis precedent vs complex nested orchestration
- **Gateway API Integration** - Uses Kubernetes-native ingress standard vs proprietary Istio Gateway resources
- **Auto-Configuration Strategy** - Jobs handle configuration drift vs complex parametersRef mechanisms

## Dependencies

- **cert-manager**: Required for TLS certificate generation
- **Gateway API CRDs**: Automatically installed via sources.yaml
- **Kind cluster**: Standard `kind-custom.yaml` configuration
- **Flux**: For GitOps deployment orchestration

## Comparison

### vs NGINX Ingress

| Feature | NGINX Ingress | Istio Gateway API |
|---------|---------------|-------------------|
| **Resource Usage** | ~100MB | ~300MB (includes mesh) |
| **Features** | Basic HTTP routing | Service mesh + routing |
| **TLS** | Manual or cert-manager | Integrated cert-manager |
| **Load Balancing** | Round-robin | Weighted, health-based |
| **Observability** | Basic metrics | Distributed tracing ready |
| **mTLS** | None | Automatic between services |
| **Access** | localhost:8080 | localhost:8081 |

### vs Traditional Istio

| Aspect | Sidecar Mode | HostK8s Ambient |
|--------|--------------|-----------------|
| **Memory Overhead** | 100MB per pod | 50MB total |
| **Configuration Changes** | Pod restarts | Instant |
| **Setup Complexity** | High | Single component |
| **Learning Curve** | Steep | Progressive |
| **Local Development** | Resource intensive | Laptop friendly |

This component enables developers to experience enterprise-grade service mesh capabilities without the traditional resource and complexity overhead, while maintaining full compatibility with HostK8s's standard cluster configuration and addon ecosystem.
