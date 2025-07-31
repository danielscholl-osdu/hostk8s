# Registry Demo - Source Code

This directory contains the **source code** for the Registry Demo application. This demonstrates building custom Docker images and pushing them to a local registry for use in Kubernetes deployments.

## Architecture

- **Source Code Location**: `src/registry-demo/` (this directory)
- **Deployment Manifests**: `software/apps/sample/registry-demo/`
- **Registry Component**: `software/components/registry/`

This separation follows enterprise patterns where:
- Platform teams manage shared infrastructure (registry)
- Development teams maintain application source code
- Deployment manifests reference pre-built images

## Prerequisites

1. **Registry Component Deployed**:
   ```bash
   make up sample
   make registry-test  # Verify registry is accessible
   ```

2. **Environment Variables** (optional):
   ```bash
   export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   export BUILD_VERSION="1.0.0"
   ```

## Build and Push Workflow

### Using Make (Recommended)
```bash
make build src/registry-demo
```

### Using Docker Compose Directly
```bash
cd src/registry-demo

# Build the image
docker compose build

# Push to local registry
docker compose push
```

### Using Docker Commands Directly
```bash
cd src/registry-demo

# Build with metadata
docker build \
  --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --build-arg BUILD_VERSION="1.0.0" \
  -t localhost:5000/registry-demo:latest \
  .

# Push to registry
docker push localhost:5000/registry-demo:latest
```

## Validation

### Verify Image in Registry
```bash
# List registry contents
curl http://localhost:30500/v2/_catalog

# Check specific image tags
curl http://localhost:30500/v2/registry-demo/tags/list
```

### Test Registry Connectivity
```bash
# From project root
make registry-test
```

## Application Details

### Technology Stack
- **Base Image**: nginx:alpine
- **Content**: Custom HTML demonstrating registry integration
- **Build Arguments**: BUILD_DATE, BUILD_VERSION for metadata
- **Exposed Port**: 80 (HTTP)

### Source Files
- `Dockerfile` - Multi-stage build with nginx
- `index.html` - Educational web content about registry workflows
- `docker-compose.yml` - Build and push configuration
- `README.md` - This documentation

## Deployment

After building and pushing the image, deploy using:

```bash
# Deploy the application (from project root)
make deploy sample/registry-demo

# Check deployment status
make status

# Access the application
curl http://localhost:30510  # NodePort access
# or http://localhost:8080/registry-demo (if ingress enabled)
```

## Development Workflow

### 1. Modify Source Code
Edit `index.html` or `Dockerfile` as needed.

### 2. Build and Push
```bash
docker compose build && docker compose push
```

### 3. Redeploy Application
```bash
# Force Kubernetes to pull latest image
kubectl rollout restart deployment/registry-demo

# Or delete and redeploy
kubectl delete -f ../../../software/apps/sample/registry-demo/app.yaml
make deploy sample/registry-demo
```

### 4. Verify Changes
```bash
curl http://localhost:30510
```

## Integration with CI/CD

This source structure supports various CI/CD patterns:

### GitHub Actions Example
```yaml
- name: Build and Push
  working-directory: src/registry-demo
  run: |
    export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    export BUILD_VERSION=${{ github.sha }}
    docker compose build
    docker compose push
```

### GitLab CI Example
```yaml
build:
  script:
    - cd src/registry-demo
    - export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    - docker compose build
    - docker compose push
```

## Multi-Repository Pattern

In enterprise environments, this source code would typically live in a separate repository:

```
my-app-repo/                    # Separate application repository
├── Dockerfile
├── index.html
├── docker-compose.yml
└── .github/workflows/build.yml

osdu-ci-repo/                   # Infrastructure repository
├── software/components/registry/
└── software/apps/sample/registry-demo/app.yaml
```

The current monorepo structure supports learning and development while allowing easy separation later.

## Troubleshooting

### Build Failures
```bash
# Check Docker daemon
docker info

# Verify Dockerfile syntax
docker build --dry-run .
```

### Push Failures
```bash
# Verify registry connectivity
curl http://localhost:30500/v2/

# Check registry pod status
kubectl get pods -n registry

# Restart registry if needed
kubectl rollout restart deployment/registry -n registry
```

### Image Pull Issues in Kubernetes
```bash
# Check containerd registry configuration
docker exec osdu-ci-control-plane cat /etc/containerd/config.toml

# Verify image exists in registry
curl http://localhost:30500/v2/registry-demo/tags/list

# Check pod events
kubectl describe pod -l app=registry-demo
```
