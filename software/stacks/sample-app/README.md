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

The stack deploys:
- **PostgreSQL component** → CloudNativePG operator + pgAdmin UI + voting database
- **Redis component** → Redis server + Redis Commander UI
- **Voting application** → vote frontend + result backend + worker processor

## Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **Voting** | http://localhost:8080/vote | Cast votes |
| **Results** | http://localhost:8080/result | View results |
| **pgAdmin** | http://pgadmin.localhost:8080/ | Database management |
| **Redis Commander** | http://redis.localhost:8080/ | Redis monitoring |

## Stack Management

```bash
# Check status
make status

# Redeploy
make down sample-app
make up sample-app

# Force sync
make sync sample-app
```
