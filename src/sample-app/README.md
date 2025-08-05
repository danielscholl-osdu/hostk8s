# HostK8s Sample App - Complete Tutorial Progression

**The exemplary application showcasing HostK8s capabilities across all tutorial levels.**

This modern voting application demonstrates the complete HostK8s development workflow from individual app deployment to cloud production, using cutting-edge tooling and HostK8s architectural patterns.

## 🏗️ Architecture

**Modern Tech Stack:**
- **Vote Service** (Python/Flask + uv) - Collects votes, stores in Redis
- **Result Service** (Node.js/Express + Bun) - Real-time results from PostgreSQL
- **Worker Service** (Spring Boot Java 17 + Maven) - Processes votes from Redis to PostgreSQL
- **Redis Component** - Shared message queue and cache
- **PostgreSQL Component** - Shared persistent database

**HostK8s Integration:**
- **Components** - Shared Redis/PostgreSQL infrastructure
- **Apps** - Individual services connecting via K8s service discovery
- **Stacks** - Complete GitOps orchestration
- **Registry** - Local development with `make build` workflow

## 📚 Tutorial Progression

### **Level 100: Deploying Apps**
```bash
# Deploy individual apps (using pre-built images)
make deploy hostk8s-vote
make deploy hostk8s-result
make deploy hostk8s-worker

# Access locally
open http://vote.localhost
open http://result.localhost
```

### **Level 200: Shared Components**
```bash
# Deploy shared infrastructure first
kubectl apply -k software/components/redis-infrastructure
kubectl apply -k software/components/postgres-infrastructure

# Apps connect to shared components automatically
make deploy hostk8s-vote  # Connects to redis-infrastructure
make deploy hostk8s-result # Connects to postgres-infrastructure
```

### **Level 300: Software Stacks**
```bash
# Complete GitOps deployment
make up hostk8s-voting-stack

# Everything orchestrated together:
# - Components deployed first
# - Apps deployed with proper dependencies
# - Ingress, monitoring, certificates
```

### **Level 400: Development Workflows**
```bash
# Build and push to HostK8s registry
make build hostk8s-vote
make build hostk8s-result
make build hostk8s-worker

# Deploy your development images
make deploy hostk8s-vote

# Hot reload development against live K8s
cd vote/ && python app.py  # Connects to K8s Redis
cd result/ && bun dev      # Connects to K8s PostgreSQL

# VS Code debugging with K8s components
code .vscode/launch.json   # Pre-configured debug sessions
```

### **Level 500: Cloud Deployment**
```bash
# Same commands, different target
export HOSTK8S_DOMAIN=yourdomain.com
make up hostk8s-voting-stack

# Access via real domains with TLS
open https://vote.yourdomain.com
open https://result.yourdomain.com
```

## 🚀 Development Features

### **Python Vote Service (uv + Flask)**
- **uv package manager** - 10x faster than pip
- **Multi-stage Dockerfile** - Dev/prod optimized
- **Health endpoints** - `/health` for monitoring
- **K8s service discovery** - Connects to `redis-infrastructure`
- **Hot reload** - Development optimized

### **Node.js Result Service (Bun + Express)**
- **Bun runtime** - 4x faster startup than Node.js
- **ES Modules** - Modern JavaScript
- **WebSocket real-time** - Socket.io for live updates
- **Enhanced error handling** - Production-ready
- **K8s service discovery** - Connects to `postgres-infrastructure`

### **Worker Service (Spring Boot + Maven)**
- **Spring Boot 3.2** - Latest enterprise Java framework
- **Java 17** - Modern JVM with performance optimizations
- **Spring Data JPA** - PostgreSQL integration with auto-reconnect
- **Spring Data Redis** - Redis integration with connection pooling
- **Actuator endpoints** - `/actuator/health` for monitoring
- **Maven multi-stage builds** - Optimized container layers

## 🔧 HostK8s Integration Patterns

### **Registry Workflow**
```bash
# Build images and push to HostK8s registry
make build hostk8s-vote     # → localhost:5000/hostk8s-vote:latest
make build hostk8s-result   # → localhost:5000/hostk8s-result:latest
make build hostk8s-worker   # → localhost:5000/hostk8s-worker:latest
```

### **Component Connections**
```yaml
# Apps connect to components via K8s service DNS
REDIS_HOST: redis-infrastructure.redis-infrastructure.svc.cluster.local
DATABASE_URL: postgres://postgres:postgres@postgres-infrastructure.postgres-infrastructure.svc.cluster.local:5432/votes
```

### **GitOps Structure**
```
software/
├── components/
│   ├── redis-infrastructure/     # Shared Redis
│   └── postgres-infrastructure/  # Shared PostgreSQL
├── apps/
│   ├── hostk8s-vote/              # Vote service
│   ├── hostk8s-result/            # Result service
│   └── hostk8s-worker/            # Worker service
└── stack/
    └── hostk8s-voting/            # Complete stack
```

## 🎯 Quick Start Examples

### **Local Development**
```bash
# 1. Start HostK8s
make start

# 2. Deploy components
kubectl apply -k software/components/redis-infrastructure
kubectl apply -k software/components/postgres-infrastructure

# 3. Build and deploy apps
make build hostk8s-vote && make deploy hostk8s-vote
make build hostk8s-result && make deploy hostk8s-result
make build hostk8s-worker && make deploy hostk8s-worker

# 4. Access applications
open http://vote.localhost
open http://result.localhost
```

### **GitOps Deployment**
```bash
# Single command for complete stack
make up hostk8s-voting-stack

# Watch GitOps magic happen
kubectl get pods -n sample-voting --watch
```

### **Development Mode**
```bash
# Terminal 1: Start components
make start && kubectl apply -k software/components/redis-infrastructure

# Terminal 2: Local development with K8s backend
cd vote/ && python app.py  # Port 5000, connects to K8s Redis

# Terminal 3: Debug with VS Code
code . && F5  # Launch "Python: Vote Service" debug config
```

## 🌟 Why This Architecture Matters

This sample app showcases **real-world HostK8s patterns**:

1. **Shared Components** - Redis/PostgreSQL deployed once, used by multiple apps
2. **Service Discovery** - Apps find components via Kubernetes DNS
3. **GitOps Ready** - Complete stack deployable via `make up`
4. **Development Optimized** - Hot reload against live K8s components
5. **Cloud Portable** - Same commands work locally and in cloud
6. **Modern Tooling** - uv, Bun, Spring Boot showcase cutting-edge development

**This is how modern Kubernetes development should work.** 🚀
