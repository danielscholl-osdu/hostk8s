# hostk8s Applications

Sample applications for testing and demonstrating various Kubernetes deployment patterns in the OSDU-CI development environment.

## Directory Structure

Each application is organized in its own folder with a standard structure:

```
software/apps/
├── app1/           # Basic sample application
│   ├── app.yaml    # Kubernetes manifests
│   └── README.md   # App-specific documentation
├── app2/           # Advanced sample application
│   ├── app.yaml    # Kubernetes manifests
│   └── README.md   # App-specific documentation
└── README.md       # This file
```

## Available Applications

### App1 - Basic Sample
- **Type**: Simple NGINX deployment
- **Service**: NodePort (direct access)
- **Replicas**: 2 pods
- **Access**: http://localhost:8080
- **Use Case**: Basic cluster validation and learning

### App2 - Advanced Sample
- **Type**: Multi-service NGINX deployment
- **Services**: ClusterIP + LoadBalancer + Ingress
- **Replicas**: 3 pods
- **Access**: Multiple access methods
- **Use Case**: Testing MetalLB, Ingress, and advanced networking
- **Requires**: MetalLB and NGINX Ingress enabled

### App3 - Multi-Service Architecture
- **Type**: 3-tier microservices (Frontend → API → Database)
- **Services**: NodePort + ClusterIP services
- **Replicas**: 5 pods total (2 frontend, 2 API, 1 database)
- **Access**: http://localhost:8080
- **Use Case**: Service-to-service communication, microservices patterns
- **Requires**: Basic cluster (no special add-ons required)

## Deployment

### Default Deployment
Deploy the default application (app1):
```bash
make deploy
```

### Specific App Deployment
Deploy a specific application:
```bash
# Method 1: Command argument
make deploy app1
make deploy app2
make deploy app3

# Method 2: Environment variable
APP_DEPLOY=app1 make deploy
APP_DEPLOY=app2 make deploy
APP_DEPLOY=app3 make deploy
```

### Environment Configuration
Set default app in `.env` file:
```bash
APP_DEPLOY=app2  # Options: app1, app2, app3
```

## Adding New Applications

1. Create a new folder: `software/apps/appX/`
2. Add Kubernetes manifests: `software/apps/appX/app.yaml`
3. Add documentation: `software/apps/appX/README.md`
4. Deploy with: `make deploy appX`

## Cleanup

Remove deployed applications:
```bash
kubectl delete -f software/apps/app1/app.yaml
kubectl delete -f software/apps/app2/app.yaml
kubectl delete -f software/apps/app3/app.yaml
```
