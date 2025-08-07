# Helm Sample - Advanced Voting Application

A complete Helm chart example demonstrating templating, values configuration, and environment-specific deployments using the classic Docker voting app architecture.

## Features

- **Full Helm Chart**: Templates, values, and helpers
- **Microservices Architecture**: Vote, Worker, Redis, PostgreSQL, Result services
- **Environment-Specific Configs**: Development and production value overrides
- **Resource Management**: Configurable CPU/memory limits and requests
- **Ingress Support**: Conditional ingress with path-based routing
- **Scalability**: Configurable replica counts per service

## Architecture

```
┌─────────┐      ┌─────────┐      ┌──────────┐
│  Vote   │────▶ │  Redis  │◀──── │  Worker  │
│(Python) │      │ (Cache) │      │  (Java)  │
└─────────┘      └─────────┘      └──────────┘
     │                                   │
     │           ┌─────────┐             │
     └──────────▶│ Result  │◀────────────┘
                 │(Node.js)│
                 └─────────┘
                      │
                 ┌──────────┐
                 │PostgreSQL│
                 │   (DB)   │
                 └──────────┘
```

## Services

- **Vote**: Frontend voting interface (Python/Flask)
- **Redis**: In-memory data store for votes
- **Worker**: Vote processor (Java) - moves votes from Redis to PostgreSQL
- **DB**: PostgreSQL database for vote storage
- **Result**: Results display interface (Node.js)

## Deployment

### Basic Deployment
```bash
make deploy helm-sample
```

### Environment-Specific Deployment
```bash
# Development (lower resources)
helm install voting-app software/apps/helm-sample/ -f software/apps/helm-sample/values/development.yaml

# Production (higher resources, scaling)
helm install voting-app software/apps/helm-sample/ -f software/apps/helm-sample/values/production.yaml
```

### Custom Values
```bash
# Override specific values
helm install voting-app software/apps/helm-sample/ \
  --set vote.replicas=5 \
  --set vote.env.optionA="Pizza" \
  --set vote.env.optionB="Burgers"
```

## Access

- **Vote Interface**: http://localhost/vote
- **Results Interface**: http://localhost/result

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vote.replicas` | Vote service replicas | `2` |
| `vote.env.optionA` | First voting option | `"Cats"` |
| `vote.env.optionB` | Second voting option | `"Dogs"` |
| `worker.replicas` | Worker service replicas | `1` |
| `ingress.enabled` | Enable ingress | `true` |

### Environment Files

- `values/development.yaml`: Reduced resources for local development
- `values/production.yaml`: Production-ready scaling and resources

## Helm Commands

```bash
# Install
helm install voting-app software/apps/helm-sample/

# Upgrade
helm upgrade voting-app software/apps/helm-sample/

# Uninstall
helm uninstall voting-app

# Check status
helm status voting-app

# Get values
helm get values voting-app
```

## Requirements

- Helm 3.0+
- Ingress controller (NGINX recommended)
- Kubernetes 1.19+

## Use Case

Perfect for demonstrating:
- Helm chart development and templating
- Multi-service application deployment
- Environment-specific configuration management
- Microservices architecture patterns
- Resource management and scaling strategies
