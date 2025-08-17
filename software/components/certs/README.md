# Certs Component

Automated TLS certificate management for Kubernetes clusters using cert-manager with internal CA authority and certificate issuers. This component provides complete certificate infrastructure with nested dependency management.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|----------|-------------|-----------|----------------|--------------|
| cert-manager | 1 | 10m | 100m | 32Mi | 128Mi |
| cert-manager-cainjector | 1 | 10m | 100m | 32Mi | 128Mi |
| cert-manager-webhook | 1 | 10m | 100m | 32Mi | 128Mi |
| **Total Component Resources** | | **30m** | **300m** | **96Mi** | **384Mi** |

## Services & Access

| Service | Endpoint | Port | Purpose |
|---------|----------|------|---------|
| cert-manager | `cert-manager.cert-manager.svc.cluster.local` | 9402 | Certificate controller |
| cert-manager-webhook | `cert-manager-webhook.cert-manager.svc.cluster.local` | 443 | Admission webhook |
| ClusterIssuer | `cluster-ca-issuer` | - | Primary certificate issuer for applications |

## Internal Components

| Component | Source Location | Purpose | Dependencies |
|-----------|----------------|---------|--------------|
| `manager/` | `software/components/certs/manager/` | cert-manager installation | None |
| `ca/` | `software/components/certs/ca/` | Root CA certificate authority | cert-manager |
| `issuer/` | `software/components/certs/issuer/` | ClusterIssuer for automatic certificates | Root CA |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Certs Component                          │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────┐ │
│  │                 │    │                 │    │          │ │
│  │   cert-manager  │───►│    Root CA      │───►│ Issuers  │ │
│  │   installation  │    │   certificate   │    │ cluster- │ │
│  │   + webhooks    │    │   authority     │    │ ca-issuer│ │
│  │   + cainjector  │    │                 │    │          │ │
│  └─────────────────┘    └─────────────────┘    └──────────┘ │
│          │                       │                    │     │
│          ▼                       ▼                    ▼     │
│      manager/                   ca/                issuer/   │
│                                                             │
│  Internal Flux orchestration with dependency management     │
└─────────────────────────────────────────────────────────────┘
```

## Integration

Stacks reference this component in their `stack.yaml`:

```yaml
- name: component-certs
  namespace: flux-system
  path: ./software/components/certs
```

Applications automatically receive TLS certificates by creating Certificate resources:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: cluster-ca-issuer
    kind: ClusterIssuer
  dnsNames:
  - localhost
```

## Deployment

| Property | Value |
|----------|-------|
| Namespace | `cert-manager` |
| Configuration | Internal Flux orchestration with dependency management |
| Health Check | Certificate manager pod readiness |
| Key Features | Nested component architecture, automatic TLS certificates |

### Deployment Flow
| Step | Component | Result |
|------|-----------|---------|
| 1 | `manager/` | cert-manager controllers ready |
| 2 | `ca/` | Root CA certificate created |
| 3 | `issuer/` | ClusterIssuer available for use |

### Basic Operations
```bash
# Check component status
kubectl get pods -n cert-manager
kubectl get clusterissuers

# Verify certificate creation
kubectl get certificates --all-namespaces

# Check ClusterIssuer status
kubectl describe clusterissuer cluster-ca-issuer
```
