# Istio Service Mesh Component (Simplified)

A streamlined Istio implementation using **Ambient mode** and **Gateway API** for HostK8s, following the postgres/redis component pattern for simplicity and maintainability.

## Architecture

Single Flux Kustomization deploying all Istio components in dependency order:

```
┌─────────────────────────────────────────────────────────┐
│                    Istio Component                       │
├─────────────────┬─────────────────┬───────────────────┤
│   Control Plane │ Ambient Dataplane │      Gateway     │
├─────────────────┼─────────────────┼───────────────────┤
│ • Gateway CRDs  │ • CNI Plugin    │ • Gateway API     │
│ • Istio Base    │ • ZTunnel       │ • TLS Certificate │
│ • Istiod        │                 │ • Auto-patch Job │
└─────────────────┴─────────────────┴───────────────────┘
```

## Features

- **Ambient Mode**: 81% memory reduction vs sidecar mode (50MB overhead)
- **Gateway API**: Kubernetes-native ingress with auto-deployment
- **Auto-Configuration**: Job patches Gateway service for correct NodePorts
- **TLS Ready**: Automatic certificate generation via cert-manager

## Installation

```bash
# Include in a stack
resources:
  - ../../components/certs
  - ../../components/istio-simple

# Or deploy directly
kubectl apply -k software/components/istio-simple
```

## Usage

### 1. Enable Ambient Mode

```bash
# Label namespace for instant mTLS
kubectl label namespace my-app istio.io/dataplane-mode=ambient
```

See `examples/enable-ambient.yaml` for complete example.

### 2. Expose Services

```bash
# Create HTTPRoute for your service
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: my-app
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
EOF
```

See `examples/httproute-sample.yaml` for advanced patterns.

### 3. Optional L7 Features

Deploy waypoint proxy for HTTP-level features:

```bash
kubectl apply -f examples/waypoint-l7.yaml
```

## Key Simplifications

Compared to the complex nested component approach, this version:

✅ **Single Flux Kustomization** (not 3 separate ones)
✅ **Dependency order in single file** (easier to understand)
✅ **Auto-patching job** (solves NodePort configuration automatically)
✅ **Examples separated** (core vs usage documentation)
✅ **Follows HostK8s patterns** (like postgres/redis components)

## Resource Usage

- **Control Plane**: ~150MB (istiod)
- **Ambient Dataplane**: ~50MB (ztunnel)
- **Gateway**: ~64MB (auto-deployed)
- **Total**: ~264MB (vs 1.3GB+ with sidecars)

## Troubleshooting

```bash
# Check all components
kubectl get pods -n istio-system

# Verify Ambient mode
kubectl get namespace -L istio.io/dataplane-mode

# Check Gateway
kubectl get gateway hostk8s-gateway -n istio-system

# Test connectivity
curl http://localhost:8080/your-app
```

## Dependencies

- **cert-manager**: Required for TLS certificates
- **Flux**: For GitOps deployment
- **Gateway API CRDs**: Automatically installed

## Comparison

| Aspect | Complex Version | Simplified Version |
|--------|-----------------|-------------------|
| **Files** | 18 files | 8 files |
| **Flux Kustomizations** | 3 (nested) | 1 (linear) |
| **Config Strategy** | Failed parametersRef | Working auto-patch |
| **Examples** | Mixed with core | Separated clearly |
| **Maintenance** | High complexity | Simple patterns |

This simplified version provides **identical functionality** with **50% fewer files** and **much clearer architecture**.
