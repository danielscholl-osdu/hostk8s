# Sample Stack

A complete GitOps demonstration stack showcasing the **component/application separation pattern** for production-ready Kubernetes deployments. This stack provides a complete web application with persistent storage, TLS certificates, and HTTP/HTTPS routing via NGINX ingress.

## Resource Requirements

| Component | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|-----------|----------|-------------|-----------|----------------|--------------|---------|
| **Applications** |
| sample-api | 1 | 50m | 200m | 128Mi | 256Mi | 1Gi PVC |
| sample-website | 2 | 25m × 2 | 50m × 2 | 32Mi × 2 | 64Mi × 2 | - |
| **Stack Components** |
| ingress-nginx-controller | 1 | 50m | 300m | 64Mi | 256Mi | - |
| **Total Stack Resources** | | **150m** | **600m** | **256Mi** | **640Mi** | **1Gi** |

## Components

| Component | Source Location | Purpose |
|-----------|----------------|---------|
| `component-metrics-server` | `software/components/` | Resource monitoring and HPA support |
| `component-certs` | `software/components/` | TLS certificate management (cert-manager + CA + issuers) |
| `component-ingress-nginx` | `software/stacks/sample/` | HTTP/HTTPS routing with Kind NodePort config |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Traffic Flow                              │
│         HTTP:8080 / HTTPS:8443 → NGINX Ingress Controller           │
│                    ├─ / → sample-website (static)                   │
│                    └─ /api → sample-api (Node.js + storage)         │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│                           Applications                                │
│  ┌─────────────────────┐           ┌─────────────────────────────────┐│
│  │   sample-website    │  DNS      │          sample-api             ││
│  │   (NGINX static)    │◄─────────►│   (Node.js + persistent vol)    ││
│  │   Namespace: sample │           │      Namespace: sample          ││
│  └─────────────────────┘           └─────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (depends on)
┌─────────────────────────────────────────────────────────────────────┐
│                        Stack Components                             │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │  component-ingress-nginx (HTTP/HTTPS routing + TLS)             ││
│  │  • NodePort 30080/30443 for Kind compatibility                  ││
│  │  • Automatic certificate integration                            ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (depends on)
┌────────────────────────────────────────────────────────────────────────┐
│                           Shared Components                            │
│  ┌─────────────────┐    ┌─────────────────────────────────────────────┐│
│  │component-metrics│    │             component-certs                 ││
│  │server           │    │  ┌─────────────────────────────────────────┐││
│  │• HPA support    │    │  │ manager → ca → issuer (nested deps)     │││
│  │• Resource mon   │    │  │ • cert-manager installation             │││
│  │                 │    │  │ • Root CA certificate                   │││
│  │                 │    │  │ • ClusterIssuer for auto-TLS            │││
│  │                 │    │  └─────────────────────────────────────────┘││
│  └─────────────────┘    └─────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────────────┘
```

## Applications

### Sample Web Interface
- **Path**: `/` (HTTP: 8080, HTTPS: 8443)
- **Purpose**: Interactive dashboard showing GitOps resources and testing capabilities
- **Runtime**: NGINX serving static HTML/CSS/JavaScript from ConfigMap
- **Features**: Real-time API testing, storage operations, GitOps resource visualization

### Sample API Service
- **Path**: `/api` (HTTP: 8080, HTTPS: 8443)
- **Purpose**: Backend service demonstrating persistent storage and health monitoring
- **Runtime**: Node.js Express server with file system operations
- **Storage**: Persistent volume mounted at `/app/storage`
- **Endpoints**:
  - `GET /api/` - Service information
  - `GET /api/health` - Health check endpoint
  - `POST /api/storage/test` - Create test file
  - `GET /api/storage/test` - Read test file content
  - `DELETE /api/storage/test` - Remove test file

## Deployment

### GitOps Files
| File | Purpose |
|------|---------|
| `kustomization.yaml` | Main orchestrator - defines what gets deployed |
| `repository.yaml` | GitOps source configuration - points to Git repository |
| `stack.yaml` | Component inventory - lists infrastructure components to deploy |
| `app/` | Application definitions - business logic services |

### Deployment Flow
| Step | File | Flux Action | Result |
|------|------|-------------|---------|
| 1 | `repository.yaml` | Connects to Git source | GitOps source established |
| 2 | `kustomization.yaml` | Orchestrates deployment order | Dependencies resolved |
| 3 | `stack.yaml` | Deploys infrastructure components | Foundation ready |
| 4 | `app/` | Deploys application services | Business logic running |

### Platform Integration
This stack is designed to integrate with the **HostK8s platform** and requires environment variable substitution (`${GITOPS_REPO}`, `${GITOPS_BRANCH}`) for GitOps deployment. It cannot be deployed directly with kubectl alone.

Use HostK8s commands to deploy and manage this stack across all supported platforms (Mac, Linux, Windows). All components are deployed and removed together as part of this stack's lifecycle.
