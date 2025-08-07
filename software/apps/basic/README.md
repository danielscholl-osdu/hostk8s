# Complex - Multi-Service Application

A comprehensive NGINX application demonstrating multiple Kubernetes service types and ingress patterns.

## Features
- Multi-replica NGINX deployment (3 pods)
- Multiple service types: ClusterIP, LoadBalancer, and Ingress
- MetalLB LoadBalancer integration
- NGINX Ingress Controller routing
- Advanced resource management
- Interactive web interface with pod hostname detection

## Services
- **ClusterIP**: Internal cluster communication
- **LoadBalancer**: External access via MetalLB (gets external IP)
- **Ingress**: HTTP routing via NGINX Ingress Controller

## Access Options
- **Ingress**: http://localhost:8080 (via NGINX Ingress)
- **LoadBalancer**: Direct access to assigned external IP
- **Path-based**: http://localhost:8080/sample-app

## Use Case
Perfect for:
- Testing MetalLB LoadBalancer functionality
- NGINX Ingress Controller validation
- Multi-service deployment patterns
- Advanced Kubernetes networking
- Production-like deployment scenarios

## Deploy
```bash
make deploy complex
# or
kubectl apply -k software/apps/complex/
```

## Requirements
- MetalLB enabled (`METALLB_ENABLED=true`)
- NGINX Ingress enabled (`INGRESS_ENABLED=true`)
