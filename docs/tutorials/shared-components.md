# Using Shared Components

*Learn to connect applications to pre-built HostK8s infrastructure services*

| **Time** | **Level** | **Prerequisites** |
|----------|-----------|-------------------|
| 20-30 minutes | 150 (Beginner-Intermediate) | Level 100 (Apps tutorial) |

## Overview

In the [Apps tutorial](apps.md), you built a voting application where every service was self-contained. While this worked perfectly, you also learned why this approach doesn't scale - imagine 10 applications each with their own Redis instance!

**Shared Components** solve this problem by providing reusable infrastructure services that multiple applications can consume. Instead of each app managing its own Redis, they all connect to one well-managed Redis **component**.

In this tutorial, you'll learn to **use** pre-built HostK8s components (not build them - that's Level 200). This focuses on consumption patterns and demonstrates the efficiency gains of shared infrastructure.

**What You'll Build:**
- Deploy pre-built Redis Infrastructure Component
- Connect voting app to shared Redis (instead of its own Redis)
- Compare resource usage between approaches
- Understand when shared components make sense

**What You'll Learn:**
- HostK8s component consumption patterns
- Service discovery across namespaces
- Resource efficiency through infrastructure sharing
- Trade-offs between individual and shared services

**Prerequisites:**
- **Completed Level 100** - You should understand the voting app and individual service patterns
- **Running HostK8s cluster** - `make start` should show healthy cluster

**Resource Expectations:**
- **Component deployment**: 1-2 minutes for Redis + Commander
- **Memory savings**: ~50% reduction compared to individual Redis instances
- **Management overhead**: Single Redis instance vs multiple instances

## Contents

1. [The Resource Waste Problem](#part-1-the-resource-waste-problem)
2. [Deploying Pre-built Components](#part-2-deploying-pre-built-components)
3. [Connecting Apps to Components](#part-3-connecting-apps-to-components)
4. [Testing Shared Infrastructure](#part-4-testing-shared-infrastructure)
5. [Resource Efficiency Demonstration](#part-5-resource-efficiency-demonstration)
6. [Understanding Trade-offs](#part-6-understanding-trade-offs)

---

## Part 1: The Resource Waste Problem

### Recap: Individual Services Approach

In Level 100, you deployed this architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Voting App    │    │   Chat App      │    │   API Service   │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Redis   │  │    │  │   Redis   │  │    │  │   Redis   │  │
│  │  Instance │  │    │  │  Instance │  │    │  │  Instance │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘

Problem: 3 Redis instances = 3x resources, 3x management overhead
```

### The Shared Component Solution

**HostK8s Shared Components** eliminate this duplication:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Voting App    │    │   Chat App      │    │   API Service   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────┬───────────────┬──────────────┘
                         │               │
              ┌─────────────────────────────────┐
              │    Redis Infrastructure         │
              │        Component                │
              │  ┌───────────┐ ┌─────────────┐ │
              │  │   Redis   │ │    Redis    │ │
              │  │  Server   │ │  Commander  │ │
              │  └───────────┘ └─────────────┘ │
              └─────────────────────────────────┘

Solution: 1 Redis component serves all applications
```

### Why This Matters

**Efficiency Benefits:**
- **Resource Usage**: 1 Redis instance vs N Redis instances
- **Management**: Single configuration, monitoring, and updates
- **Data Sharing**: Applications can share cached data when beneficial

**HostK8s Component Benefits:**
- **Pre-built and tested** - No manual YAML creation required
- **Follows HostK8s patterns** - Consistent labeling, naming, structure
- **Production-ready** - Health checks, persistence, monitoring included

---

## Part 2: Deploying Pre-built Components

### Understanding HostK8s Components

HostK8s components are **pre-built infrastructure services** that follow standard patterns:

```
software/components/redis-infrastructure/
├── kustomization.yaml     # Component definition
├── namespace.yaml         # Isolated namespace
├── redis-deployment.yaml  # Redis server
├── redis-service.yaml     # Internal service
├── commander-*.yaml       # Management UI
└── README.md             # Component documentation
```

**Key HostK8s Component Patterns:**
- **Namespace isolation**: Each component gets its own namespace
- **Standard labeling**: `hostk8s.component: redis-infrastructure`
- **Service discovery**: Predictable DNS names for applications
- **Health monitoring**: Built-in health checks and monitoring

### Deploy the Redis Infrastructure Component

Deploy the pre-built Redis component:

```bash
# Deploy the pre-built Redis Infrastructure Component
kubectl apply -k software/components/redis-infrastructure/
```

**What happens:**
- HostK8s creates the `redis-infrastructure` namespace
- Redis server starts with persistent storage and configuration
- Redis Commander UI connects to Redis for management
- Internal and external services become available

### Monitor Component Deployment

Watch the component come online:

```bash
# Check all component resources
kubectl get all -n redis-infrastructure

# Watch pods start up
kubectl get pods -n redis-infrastructure -w

# Check component health
kubectl get pods -n redis-infrastructure -l hostk8s.component=redis-infrastructure
```

You should see:
```
NAME                               READY   STATUS    RESTARTS   AGE
redis-7d58c54d4b-xyz              1/1     Running   0          2m
redis-commander-6b9b8c7d4f-abc    1/1     Running   0          2m
```

### Access the Management Interface

The Redis component includes a web-based management interface:

```bash
# Open Redis Commander
open http://localhost:30081
# Login: admin / admin
```

**What you should see:**
- Redis Commander web interface
- Connection to your Redis component
- Database browser and statistics
- Real-time monitoring capabilities

**Checkpoint ✅**: Component deployed successfully when both pods are Running and Redis Commander loads in your browser.

---

## Part 3: Connecting Apps to Components

### HostK8s Service Discovery Pattern

Applications connect to components using **standard Kubernetes DNS**:

```
Service DNS Format: <service-name>.<namespace>.svc.cluster.local
Redis Component: redis.redis-infrastructure.svc.cluster.local:6379
```

This is a **HostK8s pattern** - components provide predictable service discovery names that applications can rely on.

### Create Voting App with Shared Redis

Create a new version of the voting app that uses the shared component:

```bash
mkdir -p software/apps/extension/voting-app-shared
cd software/apps/extension/voting-app-shared
```

Create the modified application:

```bash
cat > app.yaml << 'EOF'
# Voting Application - Using Shared Redis Component
# Demonstrates HostK8s component consumption patterns

# Vote Service (connects to shared Redis)
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
        # HostK8s component connection pattern
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

# Worker Service (connects to shared Redis)
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
        # HostK8s component connection pattern
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

# PostgreSQL Database (still individual for now)
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

# Result Service
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

### Key Differences from Level 100

**What's Different:**
- **No Redis deployment** - Uses shared Redis Infrastructure Component
- **Service discovery** - Connects via `redis.redis-infrastructure.svc.cluster.local`
- **Component labeling** - `uses-component: redis-infrastructure` label
- **Different ports** - 30082/30083 to avoid conflicts with original voting app

**What's the Same:**
- PostgreSQL database (still individual - could be shared in advanced tutorials)
- Worker, Vote, and Result services function identically
- Same voting application workflow

### Deploy the Shared Version

```bash
# Deploy the voting app that uses shared Redis
make deploy extension/voting-app-shared
```

---

## Part 4: Testing Shared Infrastructure

### Test the Shared Voting App

Access the voting application:

```bash
# Vote interface (different port from Level 100)
open http://localhost:30082

# Results interface
open http://localhost:30083
```

**Test the workflow:**
1. Cast votes at http://localhost:30082
2. View results at http://localhost:30083
3. Verify real-time updates work

### Verify Component Integration

Check that the voting app is using the shared Redis:

```bash
# View Redis data through Redis Commander
open http://localhost:30081

# Or check Redis directly
kubectl exec -n redis-infrastructure deployment/redis -it -- redis-cli -a devpassword KEYS "*"
```

**What you should see:**
- Vote data in Redis Commander interface
- Keys from the voting application in Redis
- Real-time data updates as you vote

### Test Component Sharing

Deploy the original voting app alongside the shared version:

```bash
# Deploy the original voting app (if not already deployed)
make deploy extension/voting-app
```

Now you have:
- **Original voting app** (ports 30080/30081) with individual Redis
- **Shared voting app** (ports 30082/30083) using shared Redis component

**Checkpoint ✅**: Both voting apps work, but only the shared version shows data in Redis Commander at port 30081.

---

## Part 5: Resource Efficiency Demonstration

### Compare Resource Usage

Check resource consumption between approaches:

```bash
# Individual Redis approach (original voting app)
kubectl top pods -l hostk8s.app=voting-app
echo "Individual Redis pods:"
kubectl get pods -l app=redis -o wide

# Shared component approach
kubectl top pods -l hostk8s.app=voting-app-shared
kubectl top pods -n redis-infrastructure
echo "Shared Redis component:"
kubectl get pods -n redis-infrastructure -o wide
```

### Resource Usage Analysis

**Individual Redis (Level 100 approach):**
- Each app has its own Redis pod
- Memory: ~64MB per Redis instance
- CPU: ~25-50m per Redis instance
- Management: Multiple Redis configurations

**Shared Component (Level 150 approach):**
- One Redis component serves multiple apps
- Memory: ~128MB total (with management UI)
- CPU: ~100m total (with management UI)
- Management: Single Redis configuration

**Efficiency Gains:**
```
2 Apps with Individual Redis:
- Redis memory: 64MB × 2 = 128MB
- Management overhead: 2 configurations
- Data isolation: Complete

2 Apps with Shared Component:
- Redis memory: 128MB total (including Commander UI)
- Management overhead: 1 configuration
- Data sharing: Possible when beneficial
- Bonus: Web-based management interface
```

### Scale Demonstration

Imagine the efficiency at scale:

```bash
# Scale the shared voting app
kubectl scale deployment vote --replicas=3 -n default
kubectl scale deployment worker-shared --replicas=2 -n default

# The Redis component handles the load without scaling
kubectl get pods -n redis-infrastructure
```

**Scaling Benefits:**
- Applications scale independently
- Shared component handles increased load
- No additional Redis instances needed
- Centralized monitoring and management

---

## Part 6: Understanding Trade-offs

### ✅ Pros of Shared Components

**Resource Efficiency:**
- Significant memory and CPU savings
- Reduced storage requirements
- Lower cluster resource consumption

**Management Benefits:**
- Single configuration to maintain
- Centralized monitoring and updates
- Consistent version across applications
- Easier troubleshooting and debugging

**Operational Advantages:**
- Shared data when beneficial (caching, sessions)
- Standardized HostK8s patterns
- Pre-built, tested components
- Professional management interfaces

### ❌ Cons of Shared Components

**Reduced Isolation:**
- Applications depend on shared infrastructure
- Component failure affects multiple applications
- Potential for resource contention

**Less Flexibility:**
- Shared configuration may not fit all use cases
- Applications must adapt to component patterns
- Limited customization compared to individual services

**Operational Dependencies:**
- Need to understand component lifecycle
- Cross-namespace service discovery required
- Component version coordination across teams

### When to Use Shared Components

**✅ Use shared components when:**
- Multiple applications need the same infrastructure
- Resource efficiency is important
- Consistent configuration is beneficial
- Team has operational expertise to manage shared services
- Applications can tolerate shared dependencies

**❌ Stick with individual services when:**
- Applications have unique infrastructure requirements
- Complete isolation is critical
- You're prototyping or learning
- Applications are completely independent
- Customization needs exceed component flexibility

### HostK8s Recommendation

**Start with individual services (Level 100)** to understand the pieces, then **move to shared components (Level 150)** when you understand the benefits and trade-offs.

HostK8s makes both approaches easy:
- `make deploy my-app` for individual services
- `kubectl apply -k software/components/redis-infrastructure/` for shared components

---

## Part 7: Next Steps

### What You Accomplished

**✅ HostK8s Component Consumption:**
- Deployed pre-built Redis Infrastructure Component
- Connected applications to shared infrastructure services
- Used HostK8s service discovery patterns across namespaces

**✅ Resource Efficiency Understanding:**
- Demonstrated memory and CPU savings through sharing
- Compared individual vs shared approaches quantitatively
- Understood scaling benefits of shared components

**✅ Trade-off Analysis:**
- Learned honest pros/cons of shared infrastructure
- Understood when to use each approach
- Made informed decisions about component usage

### The Learning Progression

**🎯 Level 100 (Completed)**: Individual apps - understood all the pieces
**🔧 Level 150 (Completed)**: Shared components - learned to consume pre-built infrastructure
**🏗️ Level 200 (Next)**: Building components - understand how components are designed
**⚡ Level 250 (Later)**: GitOps automation - automatic component deployment
**🚀 Level 300 (Advanced)**: Software stacks - complete environment orchestration

### Immediate Next Steps

**Experiment with Components:**
```bash
# Try different component configurations
kubectl edit configmap redis-config -n redis-infrastructure

# Scale applications against shared component
kubectl scale deployment vote --replicas=5

# Monitor shared component performance
kubectl top pods -n redis-infrastructure
```

**Explore Component Patterns:**
- Look at other HostK8s components in `software/components/`
- Understand how components follow HostK8s labeling patterns
- Practice service discovery with different applications

### Bridge to Level 200

**Questions for Level 200:**
- How are HostK8s components designed and structured?
- What makes a good component vs a poor component?
- How do you customize components for different needs?
- When should you build your own components?

**Level 200 Preview**: You'll understand HostK8s component design patterns, learn to customize existing components, and understand when to build vs use pre-built components.

### Cleanup

When you're finished experimenting:

```bash
# Remove the shared voting app
make remove extension/voting-app-shared

# Remove the Redis component
kubectl delete -k software/components/redis-infrastructure/

# Remove the original voting app if desired
make remove extension/voting-app
```

---

**🎉 Congratulations!** You now understand HostK8s shared component patterns and can make informed decisions about when to use individual services vs shared infrastructure. You've learned the consumption side of components - next you'll learn how they're designed and built.

**Ready for Level 200?** Continue to [Building Components](components.md) to understand HostK8s component design patterns and learn to customize infrastructure services for your specific needs.
