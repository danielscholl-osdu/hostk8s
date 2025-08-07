# Building Components

*Learn HostK8s component design patterns and customization techniques*

| **Time** | **Level** | **Prerequisites** |
|----------|-----------|-------------------|
| 30-40 minutes | 200 (Intermediate) | Level 100 (Apps), Level 150 (Using Shared Components) |

## Overview

In [Level 150](shared-components.md), you learned to **use** pre-built HostK8s components and connect applications to shared infrastructure. You experienced the benefits of resource efficiency and centralized management.

**Building Components** teaches you how HostK8s components are designed, when to build your own, and how to customize existing components for your specific needs.

This tutorial focuses on **HostK8s component patterns** - the design principles and structures that make components reusable and maintainable. You won't manually create YAML files (that's tedious and error-prone), but you'll understand the patterns that make components work.

**What You'll Learn:**
- HostK8s component design principles and patterns
- How to analyze and customize existing components
- When to build new components vs use existing ones
- Component lifecycle management and versioning
- How components prepare you for software stacks

**What You Won't Learn (Not Required):**
- Manual YAML file creation (provided as downloadable files)
- Redis internals or configuration details
- Kubernetes operator development
- Complex component orchestration (that's Level 250+)

**Prerequisites:**
- **Level 100 completed** - Understanding of HostK8s application patterns
- **Level 150 completed** - Experience using shared components
- **Component mindset** - Focus on HostK8s patterns, not underlying technologies

**Resource Expectations:**
- **Startup time:** 3-4 minutes for component deployment
- **Memory usage:** ~200MB for Redis + Commander
- **Storage:** 1GB persistent volume for Redis data

## Contents

1. [Component Design Principles](#part-1-component-design-principles)
2. [Analyzing the Redis Infrastructure Component](#part-2-analyzing-the-redis-infrastructure-component)
3. [HostK8s Component Patterns](#part-3-hostk8s-component-patterns)
4. [Customizing Components](#part-4-customizing-components)
5. [When to Build vs Use Components](#part-5-when-to-build-vs-use-components)
6. [Component Lifecycle Management](#part-6-component-lifecycle-management)
7. [Preparing for Software Stacks](#part-7-preparing-for-software-stacks)

---

## Part 1: Component Design Principles

### Recap: Your Journey So Far

**Level 100**: You built voting app with individual Redis - understood all the pieces
**Level 150**: You used pre-built Redis component - experienced resource efficiency
**Level 200**: Now learn how HostK8s components are designed and when to build them

### HostK8s Component Philosophy

**Components are building blocks**, not applications. Just like Lego blocks, they:

- **Do one thing well** - Redis component provides caching, database component provides storage
- **Follow standard patterns** - Consistent structure across all HostK8s components
- **Compose into larger systems** - Multiple components combine into software stacks
- **Are designed for reuse** - Same component works across different applications

### The "Good Component" Principles

**✅ Good HostK8s Components:**
- **Single responsibility** - Do one infrastructure function well
- **Standard structure** - Follow HostK8s directory and labeling patterns
- **Predictable interfaces** - Applications know how to connect to them
- **Self-contained** - Include everything needed (server, UI, storage, config)
- **Production-ready** - Health checks, monitoring, persistence included

**❌ Poor Components:**
- Try to do multiple unrelated things
- Custom structures that don't follow HostK8s patterns
- Require complex application-side configuration
- Missing operational features (monitoring, health checks)
- Tightly coupled to specific applications

### Design Pattern: Infrastructure vs Applications

**Remember from Level 150:** Your voting app used the Redis Infrastructure Component

```
┌─────────────────────────────────────────────┐
│              Your Application               │  ← Business Logic
│  ┌─────────────┐ ┌─────────────┐          │
│  │    Vote     │ │   Result    │          │
│  │  Service    │ │  Service    │          │
│  └─────────────┘ └─────────────┘          │
└─────────────┬───────────┬───────────────────┘
              │           │
              ▼           ▼
┌─────────────────────────────────────────────┐
│          Infrastructure Component           │  ← Shared Services
│  ┌─────────────┐ ┌─────────────┐          │
│  │    Redis    │ │   Redis     │          │
│  │   Server    │ │  Commander  │          │
│  └─────────────┘ └─────────────┘          │
└─────────────────────────────────────────────┘
```

**Key Insight**: Applications focus on business logic, components provide infrastructure services.

### When Components Make Sense

**✅ Build HostK8s Components When:**
- Multiple applications need the same infrastructure
- You want consistent configuration across projects
- Operational overhead of individual services is too high
- Teams benefit from shared, well-managed infrastructure

**❌ Don't Build Components When:**
- Only one application needs the service
- Applications have completely different requirements
- The service is tightly coupled to specific business logic
- Overhead of sharing exceeds benefits

### HostK8s Component Categories

**Platform Services:** Redis, databases, message queues, search engines
**Security Services:** Certificate management, authentication, secrets management
**Monitoring Services:** Metrics collection, log aggregation, tracing
**Networking Services:** Ingress controllers, service mesh, load balancers

Each category follows the same HostK8s patterns you'll learn in this tutorial.

---

## Part 2: Analyzing the Redis Infrastructure Component

### Let's Analyze a Real HostK8s Component

In Level 150, you used the Redis Infrastructure Component. Let's examine how it's designed and why it follows HostK8s patterns.

**Examine the component structure:**
```bash
# Look at the Redis Infrastructure Component you used
ls -la software/components/redis-infrastructure/
```

**You should see:**
```
├── README.md                  # Component documentation
├── kustomization.yaml         # HostK8s component definition
├── namespace.yaml             # Isolation boundary
├── redis-config.yaml          # Service configuration
├── redis-deployment.yaml     # Core service
├── redis-service.yaml        # Internal interface
├── redis-pvc.yaml            # Data persistence
├── commander-deployment.yaml  # Management interface
└── commander-service.yaml     # External interface
```

### HostK8s Component Analysis

Let's examine each piece and understand the **HostK8s patterns** (not the Redis details):

### Component Design Principles

**1. Namespace Isolation**
- Each component gets its own namespace
- Clear separation from applications
- Consistent naming: `{component-name}` namespace

**2. Standardized Labels**
- All resources labeled with `hostk8s.component: {component-name}`
- Enables component-wide operations and monitoring
- Consistent with HostK8s labeling patterns

**3. Service Exposure Patterns**
- **Internal services**: ClusterIP for app-to-component communication
- **Management interfaces**: NodePort for human access
- **Optional LoadBalancer**: For external access when needed

**4. Configuration Management**
- Environment-specific customization via ConfigMaps
- Sensitive data via Secrets
- Reasonable defaults for development environments

**5. Resource Management**
- Appropriate CPU/memory requests and limits
- Persistent storage for stateful services
- Health checks for reliability

### Component vs Application Comparison

Let's compare the voting app (from Apps tutorial) with our Redis component:

**Voting App (Application):**
- Purpose: Let users vote between cats and dogs
- Consumers: Human users via web browser
- Services: All services exposed via NodePort for user access
- Data: Application-specific (votes, results)

**Redis Component (Infrastructure):**
- Purpose: Provide caching and data storage for applications
- Consumers: Other applications via internal services
- Services: Redis internal (ClusterIP), Commander external (NodePort)
- Data: Shared across multiple applications

---

## Part 3: Building the Redis Infrastructure Component

### Step 1: Create Component Directory Structure

Create the directory structure for your Redis component:

```bash
mkdir -p software/components/redis-infrastructure
cd software/components/redis-infrastructure
```

### Step 2: Create Component Namespace

Create `namespace.yaml` to isolate the component:

```bash
cat > namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    component.hostk8s.io/type: infrastructure
    component.hostk8s.io/category: database
EOF
```

### Step 3: Create Redis Persistent Storage

Create `redis-pvc.yaml` for data persistence:

```bash
cat > redis-pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    app: redis
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
EOF
```

### Step 4: Create Redis Configuration

Create `redis-config.yaml` for Redis settings:

```bash
cat > redis-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    app: redis
data:
  redis.conf: |
    # Redis configuration for HostK8s development
    bind 0.0.0.0
    port 6379

    # Persistence configuration
    save 900 1      # Save snapshot if at least 1 key changed in 900 seconds
    save 300 10     # Save snapshot if at least 10 keys changed in 300 seconds
    save 60 10000   # Save snapshot if at least 10000 keys changed in 60 seconds

    # Memory management
    maxmemory 256mb
    maxmemory-policy allkeys-lru

    # Security (basic for development)
    requirepass devpassword

    # Logging
    loglevel notice
EOF
```

### Step 5: Create Redis Deployment

Create `redis-deployment.yaml`:

```bash
cat > redis-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    app: redis
    component: server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
      component: server
  template:
    metadata:
      labels:
        app: redis
        component: server
        hostk8s.component: redis-infrastructure
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: redis
        command:
          - redis-server
          - /etc/redis/redis.conf
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /etc/redis
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - devpassword
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - -a
            - devpassword
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-data
      - name: redis-config
        configMap:
          name: redis-config
EOF
```

### Step 6: Create Redis Internal Service

Create `redis-service.yaml` for application access:

```bash
cat > redis-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    app: redis
    component: server
spec:
  selector:
    app: redis
    component: server
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  type: ClusterIP
EOF
```

### Step 7: Create Redis Commander Management UI

Create `commander-deployment.yaml`:

```bash
cat > commander-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-commander
  namespace: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    app: redis-commander
    component: management-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-commander
      component: management-ui
  template:
    metadata:
      labels:
        app: redis-commander
        component: management-ui
        hostk8s.component: redis-infrastructure
    spec:
      containers:
      - name: redis-commander
        image: rediscommander/redis-commander:latest
        ports:
        - containerPort: 8081
          name: http
        env:
        - name: REDIS_HOSTS
          value: "redis://redis.redis-infrastructure.svc.cluster.local:6379"
        - name: REDIS_PASSWORD
          value: "devpassword"
        - name: HTTP_USER
          value: "admin"
        - name: HTTP_PASSWORD
          value: "admin"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 10
          periodSeconds: 5
EOF
```

### Step 8: Create Redis Commander External Service

Create `commander-service.yaml`:

```bash
cat > commander-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis-commander
  namespace: redis-infrastructure
  labels:
    hostk8s.component: redis-infrastructure
    app: redis-commander
    component: management-ui
spec:
  selector:
    app: redis-commander
    component: management-ui
  ports:
  - port: 8081
    targetPort: 8081
    nodePort: 30081
    protocol: TCP
    name: http
  type: NodePort
EOF
```

### Step 9: Create Component Kustomization

Create `kustomization.yaml` to tie everything together:

```bash
cat > kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: redis-infrastructure
  annotations:
    component.hostk8s.io/description: "Redis infrastructure component with management UI"
    component.hostk8s.io/version: "1.0.0"

resources:
  - namespace.yaml
  - redis-config.yaml
  - redis-pvc.yaml
  - redis-deployment.yaml
  - redis-service.yaml
  - commander-deployment.yaml
  - commander-service.yaml

commonLabels:
  hostk8s.component: redis-infrastructure

images:
  - name: redis
    newTag: "7-alpine"
  - name: rediscommander/redis-commander
    newTag: "latest"
EOF
```

### Step 10: Create Component Documentation

Create `README.md`:

```bash
cat > README.md << 'EOF'
# Redis Infrastructure Component

Shared Redis infrastructure component providing caching and data storage services for HostK8s applications.

## Services

- **Redis Server**: High-performance in-memory data store with persistence
- **Redis Commander**: Web-based management interface for Redis

## Access

- **Applications**: `redis.redis-infrastructure.svc.cluster.local:6379`
- **Management UI**: http://localhost:30081 (admin/admin)
- **Password**: `devpassword` (development only)

## Architecture

```
┌─────────────────────────────────────────────┐
│           Redis Infrastructure              │
│                                             │
│  ┌─────────────┐      ┌─────────────────┐  │
│  │    Redis    │      │     Redis       │  │
│  │   Server    │◄────►│   Commander     │  │
│  │  (Internal) │      │   (External)    │  │
│  └─────────────┘      └─────────────────┘  │
│         │                       │          │
│    ClusterIP                NodePort       │
│     :6379                   :30081         │
└─────────────────────────────────────────────┘
```

## Usage from Applications

Applications can connect to Redis using the internal service:

```yaml
env:
- name: REDIS_URL
  value: "redis://:devpassword@redis.redis-infrastructure.svc.cluster.local:6379"
```

## Storage

- **Persistent Volume**: 1GB storage for Redis data
- **Persistence**: Automatic snapshots for data durability
- **Retention**: Data survives pod restarts and updates

## Monitoring

- Health checks on both Redis server and Commander
- Resource limits prevent excessive resource usage
- Management UI provides real-time Redis statistics

## Configuration

Basic Redis configuration optimized for development:
- 256MB memory limit with LRU eviction
- Automatic persistence snapshots
- Password authentication enabled
- Logging level: notice

## Commands

```bash
# Deploy component
kubectl apply -k software/components/redis-infrastructure/

# Check component status
kubectl get all -n redis-infrastructure

# View Redis logs
kubectl logs -n redis-infrastructure deployment/redis

# View Commander logs
kubectl logs -n redis-infrastructure deployment/redis-commander

# Connect to Redis CLI
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword

# Remove component
kubectl delete -k software/components/redis-infrastructure/
```
EOF
```

---

## Part 4: Testing and Validating Your Component

### Step 1: Start Your Cluster

Ensure you have a running HostK8s cluster:

```bash
make start
```

### Step 2: Deploy the Redis Component

Deploy your component using kubectl:

```bash
kubectl apply -k software/components/redis-infrastructure/
```

**What happens:**
- Namespace `redis-infrastructure` is created
- Redis server starts with persistent storage
- Redis Commander UI connects to Redis server
- Internal and external services become available

### Step 3: Monitor Component Deployment

Watch your component come online:

```bash
# Check all component resources
kubectl get all -n redis-infrastructure

# Watch pods start up
kubectl get pods -n redis-infrastructure -w

# Check persistent volume claims
kubectl get pvc -n redis-infrastructure
```

You should see output like:
```
NAME                               READY   STATUS    RESTARTS   AGE
pod/redis-7d58c54d4b-xyz          1/1     Running   0          2m
pod/redis-commander-6b9b8c7d4f-abc 1/1     Running   0          2m

NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/redis             ClusterIP   10.96.45.123   <none>        6379/TCP         2m
service/redis-commander   NodePort    10.96.87.456   <none>        8081:30081/TCP   2m

NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/redis             1/1     1            1           2m
deployment.apps/redis-commander   1/1     1            1           2m
```

### Step 4: Test Redis Server Functionality

Connect to Redis and test basic operations:

```bash
# Connect to Redis CLI
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword

# Inside Redis CLI, test basic operations:
# SET mykey "Hello from Redis Component"
# GET mykey
# KEYS *
# INFO server
# exit
```

### Step 5: Test Redis Commander Web Interface

Access the Redis Commander management interface:

```bash
# Open Redis Commander in browser
open http://localhost:30081
# Or manually visit: http://localhost:30081
```

**Login:** admin / admin

**What you should see:**
- Redis Commander web interface
- Connection to your Redis server
- Ability to browse Redis data
- Real-time server statistics
- The key you created in the CLI test

### Step 6: Test Component Persistence

Verify that data survives pod restarts:

```bash
# Add some test data
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword SET persistence-test "Component data persists"

# Restart Redis pod
kubectl delete pod -n redis-infrastructure -l app=redis

# Wait for pod to restart
kubectl wait --for=condition=ready pod -n redis-infrastructure -l app=redis --timeout=60s

# Verify data survived
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword GET persistence-test
```

### Step 7: Test Service Discovery

Verify that applications can discover your component:

```bash
# Test DNS resolution from a temporary pod
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup redis.redis-infrastructure.svc.cluster.local

# Test Redis connectivity from outside the namespace
kubectl run test-redis --image=redis:7-alpine --rm -it --restart=Never -- redis-cli -h redis.redis-infrastructure.svc.cluster.local -a devpassword ping
```

### Component Validation Checklist

Your Redis component is working when:

- **All pods running**: `kubectl get pods -n redis-infrastructure` shows 2/2 pods Running
- **Redis server accessible**: Redis CLI commands work within the pod
- **Commander UI loads**: http://localhost:30081 shows Redis Commander interface
- **Service discovery works**: Applications can resolve `redis.redis-infrastructure.svc.cluster.local`
- **Data persists**: Redis data survives pod restarts
- **Health checks pass**: Both deployments show healthy status

---

## Part 5: Integrating Components with Applications

Now let's demonstrate the power of shared components by modifying the voting app from the Apps tutorial to use your Redis component instead of its own Redis instance.

### Step 1: Deploy the Original Voting App

If you haven't already, deploy the voting app from the Apps tutorial:

```bash
# Deploy the original voting app (if not already deployed)
make deploy voting-app
```

This creates the voting app with its own Redis instance.

### Step 2: Create a Modified Voting App

Create a new version that uses your shared Redis component:

```bash
mkdir -p software/apps/voting-app-shared
cd software/apps/voting-app-shared
```

### Step 3: Create the Shared Redis Version

Create `app.yaml` that uses your Redis component:

```bash
cat > app.yaml << 'EOF'
# Voting Application - Modified to use shared Redis component
# Demonstrates component integration patterns

# Vote Service (Python Frontend)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vote
  namespace: default
  labels:
    app: vote
    hostk8s.app: voting-app-shared
    uses-component: redis-infrastructure
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vote
  template:
    metadata:
      labels:
        app: vote
        hostk8s.app: voting-app-shared
    spec:
      containers:
      - name: vote
        image: dockersamples/examplevotingapp_vote
        ports:
        - containerPort: 80
        env:
        - name: OPTION_A
          value: "Cats"
        - name: OPTION_B
          value: "Dogs"
        # Modified to use shared Redis component
        - name: REDIS_HOST
          value: "redis.redis-infrastructure.svc.cluster.local"
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_PASSWORD
          value: "devpassword"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: vote-shared
  namespace: default
  labels:
    hostk8s.app: voting-app-shared
    uses-component: redis-infrastructure
spec:
  selector:
    app: vote
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30082
  type: NodePort

# PostgreSQL Database (unchanged)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-shared
  namespace: default
  labels:
    app: db
    hostk8s.app: voting-app-shared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
        hostk8s.app: voting-app-shared
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "postgres"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          value: "postgres"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: db-shared
  namespace: default
  labels:
    hostk8s.app: voting-app-shared
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432

# Worker Service - Modified to use shared Redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker-shared
  namespace: default
  labels:
    app: worker
    hostk8s.app: voting-app-shared
    uses-component: redis-infrastructure
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
        hostk8s.app: voting-app-shared
    spec:
      containers:
      - name: worker
        image: dockersamples/examplevotingapp_worker
        env:
        # Modified to use shared Redis component
        - name: REDIS_HOST
          value: "redis.redis-infrastructure.svc.cluster.local"
        - name: REDIS_PASSWORD
          value: "devpassword"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"

# Result Service (Node.js Results Dashboard)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: result-shared
  namespace: default
  labels:
    app: result
    hostk8s.app: voting-app-shared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: result
  template:
    metadata:
      labels:
        app: result
        hostk8s.app: voting-app-shared
    spec:
      containers:
      - name: result
        image: dockersamples/examplevotingapp_result
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: result-shared
  namespace: default
  labels:
    hostk8s.app: voting-app-shared
spec:
  selector:
    app: result
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30083
  type: NodePort
EOF
```

### Step 4: Create README for Shared Version

Create `README.md`:

```bash
cat > README.md << 'EOF'
# Voting Application - Shared Component Version

Modified version of the voting application that demonstrates shared component integration by using the Redis Infrastructure Component instead of its own Redis instance.

## Architecture

This version removes the built-in Redis service and instead connects to the shared Redis Infrastructure Component:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Vote Web App  │    │  Results Web    │    │     Worker      │
│   (Python)      │    │    (Node.js)    │    │    (.NET)       │
│  Port: 30082    │    │  Port: 30083    │    │   (Background)  │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                     ┌───────────▼────────────┐
                     │    Redis Infrastructure │
                     │       Component        │
                     │  (redis-infrastructure │
                     │      namespace)        │
                     └────────────────────────┘
                                 │
                     ┌───────────▼────────────┐
                     │    PostgreSQL DB       │
                     │    (app-specific)      │
                     └────────────────────────┘
```

## Key Differences from Original

- **No Redis Deployment**: Uses shared Redis Infrastructure Component
- **Service Discovery**: Connects via `redis.redis-infrastructure.svc.cluster.local`
- **Component Dependency**: Requires Redis Infrastructure Component to be deployed first
- **Shared Data**: Multiple applications can share the same Redis instance

## Access

- Vote: http://localhost:30082 (different port from original)
- Results: http://localhost:30083 (different port from original)
- Redis Management: http://localhost:30081 (via Redis Commander)

## Prerequisites

The Redis Infrastructure Component must be deployed first:

```bash
kubectl apply -k software/components/redis-infrastructure/
```

## Deploy

```bash
make deploy voting-app-shared
# or
kubectl apply -f software/apps/voting-app-shared/app.yaml
```

## Verification

You can verify component integration by:

1. **Voting**: Cast votes at http://localhost:30082
2. **Redis Commander**: View vote data at http://localhost:30081
3. **Results**: See processed results at http://localhost:30083
4. **Shared Data**: Deploy multiple apps using the same Redis component

## Benefits Demonstrated

- **Resource Efficiency**: Single Redis instance serves multiple applications
- **Centralized Management**: One Redis Commander manages all Redis data
- **Data Sharing**: Applications can share cached data when appropriate
- **Component Reusability**: Same Redis component can be used by different app types
EOF
```

### Step 5: Deploy the Shared Component Version

Deploy the modified voting app:

```bash
make deploy voting-app-shared
```

### Step 6: Test Component Integration

Verify that both applications work with the shared component:

**Test the shared voting app:**
```bash
# Vote on the shared version
open http://localhost:30082

# View results on the shared version
open http://localhost:30083

# View Redis data in Redis Commander
open http://localhost:30081
```

**Verify shared data:**
```bash
# Check Redis for voting data from both apps
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword KEYS "*"

# You should see keys from the voting applications
```

### Step 7: Demonstrate Resource Efficiency

Compare resource usage between the two approaches:

```bash
# Resource usage with individual Redis instances
kubectl top pods -l hostk8s.app=voting-app

# Resource usage with shared component
kubectl top pods -l hostk8s.app=voting-app-shared
kubectl top pods -n redis-infrastructure

# Count total Redis pods
echo "Individual Redis approach:"
kubectl get pods --all-namespaces | grep redis | wc -l

echo "Shared component approach:"
kubectl get pods -n redis-infrastructure | grep redis | wc -l
```

### Component Integration Benefits

**What you've demonstrated:**
- **Single Infrastructure**: One Redis component serves multiple applications
- **Service Discovery**: Applications find components via DNS
- **Resource Efficiency**: Reduced memory and CPU usage
- **Centralized Management**: One Redis Commander for all applications
- **Data Visibility**: Shared Redis data visible across applications

---

## Part 6: Component Management and Operations

### Component Lifecycle Operations

**Check Component Health:**
```bash
# Overall component status
kubectl get all -n redis-infrastructure

# Component-specific resources
kubectl get pods,svc,pvc -n redis-infrastructure -l hostk8s.component=redis-infrastructure

# Check component logs
kubectl logs -n redis-infrastructure deployment/redis --tail=50
kubectl logs -n redis-infrastructure deployment/redis-commander --tail=50
```

**Update Component Configuration:**
```bash
# Update Redis configuration
kubectl edit configmap redis-config -n redis-infrastructure

# Restart Redis to pick up changes
kubectl rollout restart deployment/redis -n redis-infrastructure

# Monitor rollout
kubectl rollout status deployment/redis -n redis-infrastructure
```

**Scale Component Services:**
```bash
# Scale Redis Commander for high availability
kubectl scale deployment redis-commander --replicas=2 -n redis-infrastructure

# Note: Redis itself should remain single-instance for data consistency
```

### Component Monitoring and Troubleshooting

**Health Checks:**
```bash
# Check if Redis is responding
kubectl exec -n redis-infrastructure deployment/redis -- redis-cli -a devpassword ping

# Check Redis info
kubectl exec -n redis-infrastructure deployment/redis -- redis-cli -a devpassword info server

# Check persistence
kubectl exec -n redis-infrastructure deployment/redis -- redis-cli -a devpassword lastsave
```

**Common Issues and Solutions:**

**Redis Pod Won't Start:**
```bash
# Check pod events
kubectl describe pod -n redis-infrastructure -l app=redis

# Common causes:
# - PVC binding issues: kubectl get pvc -n redis-infrastructure
# - ConfigMap issues: kubectl get configmap redis-config -n redis-infrastructure -o yaml
# - Resource constraints: kubectl top nodes
```

**Applications Can't Connect to Redis:**
```bash
# Test service discovery
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup redis.redis-infrastructure.svc.cluster.local

# Test Redis connectivity
kubectl run test-redis --image=redis:7-alpine --rm -it --restart=Never -- redis-cli -h redis.redis-infrastructure.svc.cluster.local -a devpassword ping

# Check network policies
kubectl get networkpolicies --all-namespaces
```

**Redis Commander Can't Access Redis:**
```bash
# Check Redis Commander logs
kubectl logs -n redis-infrastructure deployment/redis-commander

# Verify Redis service
kubectl get svc redis -n redis-infrastructure

# Test connection from Commander pod
kubectl exec -n redis-infrastructure deployment/redis-commander -- wget -qO- http://redis:6379
```

### Component Security Considerations

For production deployments, consider:

**Authentication and Authorization:**
- Use Kubernetes Secrets for Redis password
- Configure Redis ACLs for fine-grained access control
- Enable TLS for Redis connections

**Network Security:**
- Implement NetworkPolicies to restrict component access
- Use service mesh for encrypted communication
- Limit external access to management interfaces

**Example Security Improvements:**

```bash
# Create Redis password secret
kubectl create secret generic redis-auth \
  --from-literal=password=$(openssl rand -base64 32) \
  -n redis-infrastructure

# Update deployment to use secret
kubectl patch deployment redis -n redis-infrastructure -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "redis",
          "env": [{
            "name": "REDIS_PASSWORD",
            "valueFrom": {
              "secretKeyRef": {
                "name": "redis-auth",
                "key": "password"
              }
            }
          }]
        }]
      }
    }
  }
}'
```

---

## Part 7: Next Steps: From Components to Stacks

### Understanding the Progression

You've now mastered the three levels of HostK8s deployments:

**Level 100 - Apps:** Individual applications (voting app, simple web services)
**Level 200 - Components:** Shared infrastructure services (Redis component)
**Level 300 - Stacks:** Complete environments combining components + applications

### How Components Enable Software Stacks

Components are the building blocks that make software stacks possible:

**Without Components (Individual Apps):**
```
Stack = App1 + App2 + App3 + App1-Redis + App2-Redis + App3-Database
```
- Duplicated infrastructure
- Complex dependency management
- Resource waste

**With Components (Shared Infrastructure):**
```
Stack = Components (Redis + Database + Monitoring) + Applications (App1 + App2 + App3)
```
- Shared, efficient infrastructure
- Clear separation of concerns
- Reusable building blocks

### Preview: Software Stacks Tutorial

In the [Software Stacks tutorial](stacks.md), you'll learn to:

1. **Compose Components and Apps**: Combine your Redis component with multiple applications
2. **Manage Dependencies**: Ensure components deploy before applications that need them
3. **GitOps Automation**: Use Flux to automatically deploy and manage complete stacks
4. **Environment Management**: Deploy the same stack to different environments with variations

**Example Stack Composition:**
```yaml
# software/stack/microservices-demo/kustomization.yaml
resources:
  # Shared Components
  - ../../components/redis-infrastructure
  - ../../components/database
  - ../../components/monitoring

  # Stack Applications
  - applications/voting-app-shared
  - applications/chat-app
  - applications/api-gateway
```

### Cleanup

When you're finished with this tutorial, clean up your resources:

```bash
# Remove the shared voting app
make remove voting-app-shared

# Remove the Redis component
kubectl delete -k software/components/redis-infrastructure/

# Optional: Remove the original voting app if still deployed
make remove voting-app
```

### Key Concepts Mastered

**Component Architecture:**
- Multi-service component organization
- Namespace isolation and labeling standards
- Internal vs external service patterns
- Persistent storage for stateful services

**Shared Infrastructure Patterns:**
- Resource efficiency through sharing
- Service discovery across namespaces
- Component lifecycle management
- Application integration patterns

**Foundation for Stacks:**
- Component reusability principles
- Dependency relationship patterns
- Configuration management strategies
- Operational monitoring approaches

**You're now ready for the [Software Stacks tutorial](stacks.md)** where you'll learn to orchestrate multiple components and applications into complete development environments using GitOps automation!

### Additional Resources

- [Apps Tutorial](apps.md) - Building individual applications
- [Software Stacks Tutorial](stacks.md) - Orchestrating complete environments
- [HostK8s Architecture Guide](../architecture.md) - Deep dive into platform design
- [Available Components](../../software/components/) - Other component examples

---

**Congratulations!** You now understand how to build and manage shared infrastructure components. These reusable building blocks are essential for efficient resource utilization and provide the foundation for complex software stacks. The component patterns you've learned scale from simple development scenarios to enterprise-grade infrastructure deployments.
