# Sample App Stack

Multi-service voting application demonstrating HostK8s component composition. Uses PostgreSQL and Redis components with a custom web application.

## Prerequisites

Configure your `.env` file:
```bash
REGISTRY_ENABLED=true                  # Local container registry for built images
VAULT_ENABLED=true                     # Vault secret management for credentials
FLUX_ENABLED=true                      # GitOps deployment with Flux
```

## Quick Start

```bash
# 1. Start cluster
make start

# 2. Build application images
make build src/sample-app

# 3. Deploy stack
make up sample-app
```

## Architecture

### Components Used
- **redis component** → Provides Redis server + Redis Commander UI
- **postgres component** → Provides PostgreSQL operator + pgAdmin UI

### Application Created
- **`sample-app` namespace** → Application services container
- **`voting-db` database** → PostgreSQL cluster (in postgres namespace)
- **vote service** → Python Flask voting frontend
- **result service** → Node.js Express results backend
- **worker service** → .NET Core background processor
- **ingress** → Web routing to vote + result services
