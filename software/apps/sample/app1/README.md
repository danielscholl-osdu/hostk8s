# App1 - Basic Sample Application

A simple NGINX application demonstrating basic Kubernetes deployment patterns.

## Features
- Single container NGINX deployment
- NodePort service for direct access
- Resource limits and requests
- Custom HTML content via ConfigMap
- 2 replica pods for basic load distribution

## Access
- **URL**: http://localhost:8080
- **Service Type**: NodePort (30080)
- **Replicas**: 2

## Use Case
Perfect for:
- Testing basic cluster functionality
- Learning Kubernetes fundamentals
- Quick validation that the cluster is working
- NodePort service demonstrations

## Deploy
```bash
make deploy app1
# or
APP_DEPLOY=app1 make deploy
```
