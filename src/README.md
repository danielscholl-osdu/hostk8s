# Source Code Directory

This directory contains **application source code** that gets built into Docker images and pushed to the local registry component. This follows enterprise patterns where source code is separated from deployment manifests.

## Architecture Pattern

```
src/                                    # Application source code (this directory)
├── registry-demo/                      # Example application
│   ├── Dockerfile                      # Image build definition
│   ├── index.html                      # Application content
│   ├── docker-compose.yml              # Build and push workflow
│   └── README.md                       # Source-focused documentation

software/apps/sample/registry-demo/     # Deployment manifests
├── app.yaml                            # Kubernetes deployment manifests
└── README.md                           # Deployment-focused documentation

software/components/registry/           # Shared infrastructure component
├── deployment.yaml                     # Registry infrastructure
├── service.yaml                        # Registry service
└── ...                                 # Other registry components
```

## Why This Separation?

### Enterprise Alignment
- **Platform Teams**: Manage shared infrastructure (`software/components/`)
- **Development Teams**: Own application source code (`src/`)
- **DevOps Teams**: Manage deployment manifests (`software/apps/`)

### Repository Flexibility
- Source code can eventually move to separate repositories
- Deployment manifests remain in infrastructure repository
- Registry component provides the bridge between them

### Clear Responsibilities
- `src/` = "How to build the application"
- `software/apps/` = "How to deploy the application"
- `software/components/` = "How to provide platform services"

## Workflow

### 1. Build and Push (Source Code)
```bash
cd src/registry-demo
docker compose build && docker compose push
```

### 2. Deploy Application (Deployment Manifests)
```bash
make deploy sample/registry-demo
```

### 3. Verify Integration
```bash
make status
curl http://localhost:30510
```

## Available Applications

### registry-demo
**Purpose**: Demonstrates local registry integration with custom images

**Source Location**: `src/registry-demo/`
**Deployment Location**: `software/apps/sample/registry-demo/`

**Build Commands**:
```bash
# Using Make (recommended)
make build src/registry-demo

# Using Docker Compose directly
cd src/registry-demo
docker compose build && docker compose push

# Using Docker commands directly
cd src/registry-demo
export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
docker build --build-arg BUILD_DATE="$BUILD_DATE" -t localhost:5000/registry-demo:latest .
docker push localhost:5000/registry-demo:latest
```

## Adding New Applications

### 1. Create Source Directory
```bash
mkdir -p src/myapp
cd src/myapp
```

### 2. Create Application Files
```bash
# Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

# Application content
echo "<h1>My Application</h1>" > index.html
```

### 3. Create Docker Compose Configuration
```yaml
# docker-compose.yml
services:
  myapp:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        BUILD_DATE: ${BUILD_DATE:-}
        BUILD_VERSION: ${BUILD_VERSION:-1.0.0}
    image: localhost:5000/myapp:latest
    profiles:
      - build
```

### 4. Create Deployment Manifests
Create corresponding deployment manifests in `software/apps/sample/myapp/app.yaml` that reference `localhost:5000/myapp:latest`.

### 5. Build and Deploy
```bash
# Build and push
make build src/myapp

# Deploy
make deploy sample/myapp
```

## Docker Compose Usage

### Why Docker Compose Here?
- **NOT for orchestration**: We use Kubernetes for that
- **FOR build workflows**: Docker Compose excels at build processes
- **Consistency**: Same build process locally and in CI/CD
- **Environment Variables**: Easy to pass build-time variables

### Standard Pattern
```yaml
services:
  {app-name}:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        BUILD_DATE: ${BUILD_DATE:-}
        BUILD_VERSION: ${BUILD_VERSION:-1.0.0}
    image: localhost:5000/{app-name}:latest
    profiles:
      - build  # Prevents accidental docker compose up
```

### Environment Variables
- `BUILD_DATE`: Timestamp for image metadata
- `BUILD_VERSION`: Version tag for image metadata
- Set automatically by Make targets or manually for custom builds

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Build and Push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build and Push myapp
        working-directory: src/myapp
        env:
          BUILD_DATE: ${{ github.run_started_at }}
          BUILD_VERSION: ${{ github.sha }}
        run: |
          docker compose build
          docker compose push
```

### GitLab CI Example
```yaml
build-myapp:
  script:
    - cd src/myapp
    - export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    - export BUILD_VERSION=$CI_COMMIT_SHA
    - docker compose build
    - docker compose push
```

## Development Patterns

### Local Development
```bash
# 1. Start infrastructure
make up sample

# 2. Build application
make build src/myapp

# 3. Deploy application
make deploy sample/myapp

# 4. Iterate on source
cd src/myapp
# Edit files...
docker compose build && docker compose push
kubectl rollout restart deployment/myapp

# 5. Test changes
curl http://localhost:30XXX  # Check NodePort in app.yaml
```

### Multi-Application Development
```bash
# Build multiple applications
make build src/app1
make build src/app2
make build src/app3

# Deploy all applications
make deploy sample/app1
make deploy sample/app2
make deploy sample/app3

# Check all deployments
make status
```

## Registry Integration

### Image Naming Convention
- **Format**: `localhost:5000/{app-name}:latest`
- **Registry**: Local registry at NodePort 30500
- **Internal Resolution**: Kind resolves to `registry.registry.svc.cluster.local:5000`

### Registry Workflow
1. **Build**: Create Docker image locally
2. **Tag**: Tag as `localhost:5000/{app-name}:latest`
3. **Push**: Push to local registry via port 30500
4. **Deploy**: Kubernetes pulls from internal registry service
5. **Cache**: Image cached in Kind node for subsequent deployments

### Registry Validation
```bash
# Test registry connectivity
make registry-test

# List all images
curl http://localhost:30500/v2/_catalog

# List tags for specific image
curl http://localhost:30500/v2/myapp/tags/list
```

## Best Practices

### Source Code Structure
- **Dockerfile**: Standard Docker build instructions
- **docker-compose.yml**: Build and push configuration with profiles
- **README.md**: Source-specific documentation and build instructions
- **Application files**: Source code, static assets, configuration

### Image Guidelines
- **Base Images**: Use official, minimal base images (alpine variants preferred)
- **Metadata**: Include build arguments for BUILD_DATE and BUILD_VERSION
- **Security**: Run as non-root user when possible
- **Size**: Minimize image size with multi-stage builds
- **Caching**: Optimize layer ordering for Docker build caching

### Environment Management
- **Local**: Use localhost:5000 registry
- **CI/CD**: Can use same patterns with external registries
- **Production**: Reference production registries in deployment manifests

This structure provides clear separation of concerns while maintaining a complete local development experience that mirrors enterprise patterns.
