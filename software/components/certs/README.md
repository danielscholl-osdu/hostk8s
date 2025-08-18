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
│      manager/                   ca/               issuer/   │
│                                                             │
│  Internal Flux orchestration with dependency management     │
└─────────────────────────────────────────────────────────────┘
```

## Usage

**Stack Integration:**
```yaml
- name: component-certs
  namespace: flux-system
  path: ./software/components/certs
```

**Expected Kustomizations:**
- `component-certs` (parent component)
- `component-certs-manager` (cert-manager installation)
- `component-certs-ca` (root CA certificate)
- `component-certs-issuer` (ClusterIssuer configuration)

**Available ClusterIssuers:**

| Issuer | Purpose | Use Case |
|--------|---------|----------|
| `root-ca-cluster-issuer` | Internal CA authority | Local development, internal services |
| `letsencrypt-staging` | Let's Encrypt staging | Testing external certificates |
| `letsencrypt-production` | Let's Encrypt production | Production external certificates |

**Certificate Examples:**
```yaml
# Internal development certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
spec:
  secretName: my-app-tls-secret
  issuerRef:
    name: root-ca-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
  - localhost
  - my-app.local
---
# External certificate (staging)
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-external-tls
spec:
  secretName: my-app-external-tls-secret
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
  - my-app.example.com
```
