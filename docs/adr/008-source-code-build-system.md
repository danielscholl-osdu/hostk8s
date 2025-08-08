# ADR-008: Source Code Build System Architecture

## Status
**Accepted** - 2025-08-08

## Context
HostK8s needed a way to support development workflows that go beyond deploying pre-built applications. Developers require the ability to build, containerize, and deploy their own source code directly within the Kubernetes development environment. The platform needed to support multiple programming languages, build systems, and deployment patterns while maintaining the simplicity of the core HostK8s experience.

The existing GitOps patterns work well for pre-built applications, but create friction for iterative development where developers need to quickly build, test, and iterate on source code changes within their local Kubernetes environment.

## Decision
Implement a **comprehensive source code build system** that enables developers to build, containerize, and deploy applications directly from source code using `make build src/APP_NAME`. The system supports multiple programming languages through Docker Compose build configurations and integrates with the cluster's container registry for immediate deployment.

## Rationale
1. **Development Velocity**: Enable rapid iteration on source code within Kubernetes environments
2. **Multi-Language Support**: Accommodate diverse development stacks (Node.js, Python, Java, C#, etc.)
3. **Container-Native**: Leverage Docker Compose for consistent, reproducible builds
4. **Registry Integration**: Automatic push to cluster registry for immediate deployment
5. **Educational Value**: Provide complete examples for learning different technology stacks
6. **GitOps Compatibility**: Built containers can be deployed via standard HostK8s patterns

## Architecture Design

### Directory Structure
```
src/
├── README.md                    # Source code documentation
├── sample-app/                  # Multi-service voting application
│   ├── docker-compose.yml      # Build configuration
│   ├── docker-compose.dev.yml  # Development overrides
│   ├── result/                  # Node.js result service
│   ├── vote/                    # Python voting service
│   └── worker/                  # Java worker service
├── registry-demo/               # Simple registry demonstration
│   ├── docker-compose.yml      # Single service build
│   ├── Dockerfile              # Static HTML demo
│   └── index.html              # Application content
└── example-voting-app/          # External project integration
    ├── docker-compose.yml       # Multi-language stack
    ├── vote/                    # Python Flask
    ├── result/                  # Node.js + WebSockets
    ├── worker/                  # .NET Core
    └── k8s-specifications/      # Kubernetes manifests
```

### Build System Components

**Build Script (`infra/scripts/build.sh`)**:
- Docker Compose validation and execution
- Cluster registry integration
- Multi-service application support
- Cross-platform compatibility

**Makefile Integration**:
```makefile
build: ## Build and push application from src/
	@APP_PATH="$(word 2,$(MAKECMDGOALS))"; \
	./infra/scripts/build.sh "$$APP_PATH"
```

**Registry Integration**:
- Automatic container registry setup in cluster
- Image tagging and push workflow
- Registry authentication handling
- Cross-platform registry support (localhost:5000, localhost:5443)

### Supported Application Patterns

**Single Service Applications**:
```yaml
# src/registry-demo/docker-compose.yml
services:
  registry-demo:
    build: .
    ports:
      - "8080:80"
```

**Multi-Service Applications**:
```yaml
# src/sample-app/docker-compose.yml
services:
  vote:
    build: ./vote
    ports:
      - "5000:80"
  result:
    build: ./result
    ports:
      - "5001:80"
  worker:
    build: ./worker
```

**Development Overrides**:
```yaml
# src/sample-app/docker-compose.dev.yml
services:
  vote:
    volumes:
      - ./vote:/app
    environment:
      - FLASK_DEBUG=1
```

## Alternatives Considered

### 1. Dockerfile-Only Build System
- **Pros**: Simple, widely understood, minimal configuration
- **Cons**: Poor multi-service support, no development workflow integration
- **Decision**: Rejected due to limited multi-service capabilities

### 2. Kubernetes Job-Based Builds
- **Pros**: Cloud-native, resource management, distributed builds
- **Cons**: Complex setup, slower feedback, resource overhead
- **Decision**: Rejected due to complexity and slower iteration

### 3. Buildpacks Integration
- **Pros**: Language auto-detection, optimized images, best practices
- **Cons**: Additional dependency, learning curve, limited customization
- **Decision**: Rejected due to additional complexity

### 4. CI/CD Pipeline Integration Only
- **Pros**: Professional workflow, automated testing, deployment automation
- **Cons**: Slow feedback for local development, complex local setup
- **Decision**: Rejected for local development use case (CI/CD remains separate)

### 5. Tilt/Skaffold Integration
- **Pros**: Development-focused, hot reloading, sophisticated workflows
- **Cons**: Additional tool dependency, learning curve, complexity
- **Decision**: Rejected to maintain HostK8s simplicity

## Implementation Benefits

### Developer Experience
```bash
# Complete development workflow
make build src/sample-app        # Build all services
make deploy sample-voting-app    # Deploy to cluster
make status                      # Verify deployment
# Edit source code, repeat
```

### Multi-Language Support
- **Node.js**: Express applications with WebSocket support
- **Python**: Flask web applications with Redis integration
- **Java**: Spring Boot microservices with database connectivity
- **C#/.NET**: Worker services with message processing
- **Static Content**: HTML/CSS/JS applications

### Registry Workflow
```bash
# Automatic registry integration
make build src/my-app           # Builds and pushes to localhost:5000
kubectl get pods -n registry    # Registry running in cluster
docker images | grep localhost  # Local images available
```

## Educational Value

### Progressive Complexity Examples
1. **registry-demo**: Simple static HTML deployment
2. **sample-app**: Multi-service application with different languages
3. **example-voting-app**: Complex distributed system with external integration

### Learning Pathways
- **Container Basics**: Single-service containerization
- **Multi-Service Architecture**: Service communication and dependencies
- **Language Integration**: Multiple programming languages in one system
- **Development Workflows**: Hot reloading and iterative development

## Consequences

**Positive:**
- **Rapid Development**: Fast build-test-deploy cycles within Kubernetes
- **Multi-Language Support**: Comprehensive support for diverse technology stacks
- **Educational Excellence**: Rich examples for learning container and Kubernetes development
- **Registry Integration**: Seamless integration with cluster container registry
- **GitOps Compatibility**: Built applications deploy via standard HostK8s patterns
- **Development Workflow**: Complete source-to-deployment pipeline

**Negative:**
- **Build Dependencies**: Requires Docker Compose and appropriate language runtimes
- **Registry Complexity**: Container registry setup and management overhead
- **Disk Usage**: Source code and built images consume additional storage
- **Build Time**: Large applications with multiple services can have slow builds
- **Platform Dependencies**: Different behavior across development platforms

## Usage Patterns

### Iterative Development
```bash
# Start cluster with registry
make up sample

# Build and deploy application
make build src/sample-app
make deploy voting-app

# Make code changes
vim src/sample-app/vote/app.py

# Rebuild and redeploy
make build src/sample-app
make sync  # GitOps reconciliation
```

### Multi-Service Development
```bash
# Build complex application
make build src/example-voting-app

# Individual service development
cd src/sample-app
docker-compose up vote    # Test single service
docker-compose up         # Test full stack locally
```

## Success Criteria
- Source code builds successfully across multiple programming languages
- Built containers integrate seamlessly with cluster registry
- Development iteration cycle < 2 minutes for simple applications
- Multi-service applications build and deploy reliably
- Educational examples provide clear learning progression
- Build system works consistently across Mac, Linux, and Windows WSL2
- Integration with existing GitOps deployment patterns

## Related ADRs
- [ADR-001: Host-Mode Architecture](001-host-mode-architecture.md) - Foundation platform architecture
- [ADR-002: Make Interface Standardization](002-make-interface-standardization.md) - Interface supporting build commands
- [ADR-003: GitOps Stack Pattern](003-gitops-stack-pattern.md) - Deployment patterns for built applications
