# Sample Voting Application

Multi-service voting application demonstrating HostK8s application patterns.

## Architecture

- **Vote**: Python web app for casting votes (frontend tier)
- **Redis**: Vote queue and session storage (infrastructure tier)
- **Worker**: .NET service processing votes (backend tier)
- **Database**: PostgreSQL storing results (infrastructure tier)
- **Result**: Node.js web app showing results (frontend tier)

## Access Methods

**LoadBalancer (requires METALLB_ENABLED=true):**
- Vote: External IP from `kubectl get svc vote-lb`
- Results: External IP from `kubectl get svc result-lb`

**NodePort (always available):**
- Vote: http://localhost:30080
- Results: http://localhost:30081

**Ingress (requires INGRESS_ENABLED=true):**
- Vote: http://localhost/vote
- Results: http://localhost/results

## Commands

```bash
# Deploy application
make deploy extension/sample

# Check status
kubectl get pods -l hostk8s.app=sample

# View services
kubectl get services -l hostk8s.app=sample

# View logs
kubectl logs -l app=vote
kubectl logs -l app=result
kubectl logs -l app=worker

# Remove application
make remove extension/sample
```

## HostK8s Patterns Demonstrated

- **Kustomize Structure**: Resources organized in separate files
- **Consistent Labeling**: `hostk8s.app: sample` on all resources
- **Tier Classification**: Resources labeled by tier (frontend, backend, infrastructure)
- **Service Types**: ClusterIP for internal, LoadBalancer for external access
- **Resource Limits**: Development-appropriate CPU and memory constraints
- **Extension Pattern**: Located in `software/apps/extension/` directory
