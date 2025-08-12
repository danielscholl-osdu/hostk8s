# Advanced Sample - Simple & Reliable Voting

A clean HostK8s Advanced Sample application built with Python Flask and Redis, demonstrating modern Kubernetes deployment patterns.

## Features

- **Simple Architecture**: Just 2 services (Python Flask + Redis)
- **Real-time Results**: Vote and immediately see updated counts on the same page
- **Single Page App**: Voting interface and results in one clean UI
- **Reliable**: No complex Socket.IO, database polling, or microservice coordination
- **Configurable**: Customize title and voting options via environment variables

## Architecture

```
┌─────────────────┐      ┌─────────────┐
│  Advanced       │────▶ │    Redis    │
│  Frontend       │      │  (Counter)  │
│  (Python Flask)│      │             │
└─────────────────┘      └─────────────┘
```

## Services

- **Frontend**: Python Flask web application with voting interface and results
- **Backend**: Redis for simple vote counting (increments counters)

## Deployment

### Basic Deployment
```bash
make deploy advanced
```

### Access
- **Default namespace**: http://localhost:8080/
- **Other namespaces**: http://NAMESPACE.localhost:8080/ (e.g., http://test.localhost:8080/)

### Custom Configuration
```bash
# Override voting options
helm install my-vote software/apps/advanced/ \
  --set app.title="My Custom Vote" \
  --set app.vote1="Pizza" \
  --set app.vote2="Burgers"
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.title` | Application title | `"HostK8s Advanced Sample"` |
| `app.vote1` | First voting option | `"Kustomize"` |
| `app.vote2` | Second voting option | `"Helm"` |
| `app.showHost` | Show hostname in title | `false` |
| `frontend.replicas` | Frontend service replicas | `1` |
| `backend.replicas` | Redis replicas | `1` |
| `ingress.enabled` | Enable ingress | `true` |

**Note:** When deployed to non-default namespaces, the application uses host-based routing (e.g., `test.localhost:8080` for the `test` namespace). This ensures proper form submission handling and namespace isolation.

## Helm Commands

### Basic Commands
```bash
# Install
helm install advanced software/apps/advanced/

# Upgrade
helm upgrade advanced software/apps/advanced/

# Uninstall
helm uninstall advanced

# Check status
helm status advanced

# Get values
helm get values advanced
```

### Create a Custom Values File

Create a custom values file to override default settings. See `values.yaml` for all available configuration options with detailed comments.

```bash
# Copy and customize the values file
cp values.yaml custom_values.yaml

# Edit custom_values.yaml with your preferences
# Example: Change app title, voting options, scaling, resources
```

### Install Helm Chart

Install the helm chart with custom configuration.

```bash
# Install with custom values
helm upgrade --install advanced . -f custom_values.yaml

# Install to specific namespace
NAMESPACE=test
helm upgrade --install advanced . -n $NAMESPACE --create-namespace -f custom_values.yaml
```

### Template Preview

Preview the generated manifests before installation.

```bash
# Preview with custom values
helm template advanced . -f custom_values.yaml

# Preview with inline overrides
helm template advanced . --set app.title="Quick Test Vote"
```

## Requirements

- Kubernetes 1.19+
- Ingress controller (NGINX recommended)
- Helm 3.0+
