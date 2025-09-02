# Development Workflows

*Complete source-to-deployment development cycle with production-like environments*

## The Development Iteration Challenge

You've configured clusters, deployed applications, and built shared components. Now comes the real test: **actually building software**. You have a web service that needs to connect to a database and cache layer, but during development you need to iterate quickly on your code while testing against these production-like services.

The traditional development workflow forces an uncomfortable choice: develop in isolation with mocked services for speed, or deploy to a full environment for realism but sacrifice iteration velocity. Neither approach adequately bridges the gap between rapid code changes and production-like testing.

**The Development Velocity Dilemma:**

*Local vs Production-Like:*
- **Pure local development** - Fast iteration but can't test service interactions, networking, or resource constraints
- **Full stack deployment** - Realistic testing but slow build-deploy-test cycles kill development momentum

*Build Process Complexity:*
- **Manual containerization** - Developers spend time writing Dockerfiles instead of application code
- **Environment inconsistency** - Code works locally but fails when containerized due to different runtime environments
- **Debugging barriers** - Container layers make debugging significantly more complex than local development

*Service Dependencies:*
- **Mock services** - Fast development but poor fidelity for integration testing
- **External dependencies** - Real services but network latency and availability issues during development

**The Development Context Problem:**
You need rapid iteration on source code combined with the service complexity you've built through the previous tutorials. But traditional approaches create friction: either you develop in isolation and miss integration issues, or you accept slow containerized development cycles that destroy productivity.

## How HostK8s Solves Development Iteration

HostK8s bridges local development velocity with production-like service complexity through **hybrid development workflows**. Rather than forcing you to choose between speed and realism, the platform provides patterns that let you develop with both.

The key insight: **your source code development environment should integrate seamlessly with the infrastructure patterns you've already mastered**. The cluster configurations, application contracts, and shared components from previous tutorials become the foundation for rapid development iteration.

### The HostK8s Development Philosophy

Development workflows build directly on the patterns you've learned:
- **Cluster configurations** provide the infrastructure foundation for development
- **Application contracts** enable consistent deployment regardless of source code changes
- **Shared components** eliminate the overhead of managing development dependencies
- **Source-to-deployment automation** bridges the gap between code changes and running services

Instead of parallel development and deployment processes, HostK8s creates a unified workflow where development iteration happens within the context of your target infrastructure.

## Understanding the Complete Development Stack

Let's start by understanding what you're building toward. The sample application demonstrates a complete microservices architecture that you'll develop and deploy:

```bash
# Explore the source code structure
ls src/sample-app/
```

You'll see:
```
sample-app/
├── docker-compose.yml      # Local development environment
├── docker-bake.hcl         # Multi-service build configuration
├── vote/                   # Python voting frontend
├── result/                 # Node.js results dashboard
├── worker/                 # .NET background processor
└── seed-data/              # Database initialization
```

This represents the reality of modern application development: multiple services in different languages that must work together. Traditional development approaches force you to choose between developing these services in isolation or accepting slow full-stack deployment cycles.

### The Development Stack Architecture

The sample application illustrates the full spectrum of development complexity:

**Frontend Services** - User-facing web applications that need rapid UI iteration
**Backend Services** - API services that require database connectivity for realistic testing
**Background Workers** - Processing services that need message queue integration
**Database Dependencies** - Persistent storage that must maintain state across development sessions

Each service type presents different development challenges. Frontend services need fast refresh cycles for UI changes. Backend services need database connectivity for realistic API testing. Background workers need message queue integration to process jobs correctly. Traditional development approaches handle each poorly, forcing compromises between speed and realism.

## Local Development Foundation

Before building the complete stack, let's understand how individual service development works within the HostK8s patterns:

```bash
# Navigate to the source application
cd src/sample-app

# Start the local development environment
docker compose up
```

**What's happening:**
- All services start with their dependencies (PostgreSQL, Redis)
- Services are configured for local development with hot reload capabilities
- Database connections, service discovery, and networking work exactly as they would in production
- Each service can be developed individually while maintaining integration context

### Local Development Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                Local Development Environment                 │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │    Vote     │  │   Result    │  │   Worker    │           │
│  │  (Python)   │  │ (Node.js)   │  │   (.NET)    │           │
│  │ Port: 5000  │  │ Port: 5001  │  │(Background) │           │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘           │
│         │                │                │                  │
│         └────────────────┼────────────────┘                  │
│                          │                                   │
│         ┌────────────────┼────────────────┐                  │
│         │                │                │                  │
│    ┌────▼─────┐    ┌─────▼─────┐    ┌─────▼──────┐           │
│    │  Redis   │    │PostgreSQL │    │ Network    │           │
│    │ (Cache)  │    │(Database) │    │  (Docker)  │           │
│    └──────────┘    └───────────┘    └────────────┘           │
└──────────────────────────────────────────────────────────────┘
```

**The key insight**: Local development maintains the same service architecture you'll deploy to Kubernetes, but with development-optimized configuration (hot reload, debug ports, volume mounts for code changes).

### Development Iteration Workflow

With the local environment running, let's see rapid iteration in action:

```bash
# In a separate terminal, make a change to the voting interface
# Edit src/sample-app/vote/templates/index.html
# Change the voting options from "Cats vs Dogs" to "Coffee vs Tea"

# The change appears immediately - no rebuild required
# Open http://localhost:5000 to see the updated interface
```

**Development velocity**: Changes to Python templates, static files, and most source code appear immediately without container rebuilds. The development environment provides the speed of local development with the service complexity of your target deployment.

Stop the local environment and clean up:

```bash
# Stop local development
docker compose down

# Return to project root
cd ../..
```

## From Local to Production-Like Deployment

Local development provides rapid iteration, but you also need to test how your application behaves in the Kubernetes environment you've configured. This is where HostK8s bridges local development and production-like deployment.

### The Build and Deploy Workflow

HostK8s provides `make build` to containerize your source code and integrate it with the cluster registry:

```bash
# Ensure your cluster is running
make status

# Build the sample application and push to cluster registry
make build src/sample-app
```

**What's happening:**
- Docker Compose builds all services in the application
- Built images are tagged for the local cluster registry
- Images are pushed to the cluster registry automatically
- The cluster can now deploy your locally-built code

### Build Process Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   Source Code   │    │  Build Process  │    │ Cluster Registry │
│                 │    │                 │    │                  │
│  ┌────────────┐ │    │ ┌─────────────┐ │    │ ┌──────────────┐ │
│  │    vote    │ ├────► │Docker Build │ ├────► │localhost:5000│ │
│  │   result   │ │    │ │Multi-Service│ │    │ │   Images     │ │
│  │   worker   │ │    │ │   Images    │ │    │ │              │ │
│  └────────────┘ │    │ └─────────────┘ │    │ └──────────────┘ │
└─────────────────┘    └─────────────────┘    └──────────────────┘
                                 │                       │
                           ┌─────▼─────┐           ┌─────▼─────┐
                           │   Tag     │           │  Deploy   │
                           │ & Push    │           │   Stack   │
                           └───────────┘           └───────────┘
```

The build process transforms your source code into container images that can be deployed using the same application contracts and shared components you've already mastered.

## Deploying to Production-Like Infrastructure

Now deploy your locally-built application to the Kubernetes environment using the software stack pattern:

```bash
# Deploy the complete software stack
make up sample-app
make status
```

You'll see your application running within the full Kubernetes infrastructure:
- Your source code running as containerized services
- Shared components providing database and caching services
- Ingress routing providing external access
- The same service architecture as local development, but with production-like infrastructure

### Production-Like Development Architecture

```
┌───────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (Production-Like)             │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │    Vote     │  │   Result    │  │   Worker    │            │
│  │  (Your Code)│  │ (Your Code) │  │ (Your Code) │            │
│  │   Pod       │  │    Pod      │  │    Pod      │            │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘            │
│         │                │                │                   │
│         └────────────────┼────────────────┘                   │
│                          │                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │               Shared Components                          │ │
│  │  ┌─────────────┐    ┌─────────────┐                      │ │
│  │  │   Redis     │    │ PostgreSQL  │                      │ │
│  │  │ Component   │    │  Component  │                      │ │
│  │  └─────────────┘    └─────────────┘                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                          │                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Infrastructure                              │ │
│  │  ┌─────────────┐    ┌─────────────┐                      │ │
│  │  │   Ingress   │    │    DNS      │                      │ │
│  │  │ Controller  │    │  Service    │                      │ │
│  │  └─────────────┘    └─────────────┘                      │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

**The development advantage**: Your code is now running in the same infrastructure environment you'll deploy to production, but built from your local source code. You can test service discovery, resource limits, ingress routing, and component integration with your actual application code.

## The Complete Development Iteration Cycle

HostK8s enables a hybrid approach where you can develop locally for speed and deploy to production-like infrastructure for integration testing:

### Fast Local Iteration

```bash
cd src/sample-app

# Start local development for rapid iteration
docker compose up -d

# Make code changes, see immediate results
# Test individual services in isolation
# Debug with local development tools
```

### Production-Like Integration Testing

```bash
# Return to project root and build changes
cd ../..

# Containerize updated code
make build src/sample-app

# Deploy to Kubernetes infrastructure
make up sample-app

# Test with full service mesh, ingress, and shared components
```

### The Hybrid Development Advantage

**Local Development Phase:**
- Rapid iteration on individual services
- Immediate feedback on code changes
- Full debugging capabilities with local tools
- Isolated testing of business logic

**Integration Testing Phase:**
- Production-like infrastructure testing
- Service discovery and networking validation
- Resource constraint testing
- Component integration verification

This eliminates the traditional trade-off between development speed and production fidelity. You can iterate rapidly when building features and validate thoroughly when testing integration.

## Advanced Development Patterns

### Service-Specific Development

You can develop individual services while keeping others stable:

```bash
# Build and deploy just the voting service
make build src/sample-app --service vote
make up sample-app

# The result and worker services continue running while vote service updates
```

### Component-Aware Development

Your application automatically integrates with the shared components you've built:

```bash
# Deploy shared Redis component first
kubectl apply -k software/components/redis-infrastructure/

# Your application automatically discovers and uses the shared Redis
make up sample-app
```

The service discovery, configuration, and integration patterns you learned in previous tutorials become the foundation for production-like development.

### Development Environment Management

Different development contexts require different infrastructure:

```bash
# Minimal development cluster
make start minimal

# Full-featured development with all components
export INGRESS_ENABLED=true
export METALLB_ENABLED=true
make start
make up sample-app
```

The cluster configuration patterns from the first tutorial directly support different development workflows.

## What Comes Next

You've now experienced the complete HostK8s development workflow: from cluster configuration through application deployment to source code iteration. This completes the learning progression:

- **Cluster Configuration** - Infrastructure foundation that supports different development needs
- **Application Deployment** - Consistent deployment patterns that work for any source code
- **Shared Components** - Reusable infrastructure that eliminates development overhead
- **Development Workflows** - Rapid iteration within production-like environments

These patterns work together to eliminate the traditional trade-offs between development velocity and production fidelity. You can iterate rapidly on source code while testing against realistic infrastructure, debug locally while deploying consistently, and build individual services while integrating with shared components.

The HostK8s approach scales from individual developer workflows to team collaboration patterns. The same cluster configurations, application contracts, and development workflows that support individual development also enable consistent team environments, CI/CD integration, and production deployment patterns.

---

**Congratulations!** You now have the complete HostK8s development toolkit. You can configure infrastructure for your needs, deploy applications consistently, build reusable components, and iterate on source code within production-like environments. These patterns form the foundation for building and deploying modern applications with the velocity of local development and the realism of production infrastructure.
