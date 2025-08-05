# Deploying Apps

*Learn to create and deploy multi-service applications with HostK8s*

| **Time** | **Level** | **Prerequisites** |
|----------|-----------|-------------------|
| 30-45 minutes | 100 (Beginner) | Docker Desktop, HostK8s basics |

## Overview

HostK8s makes it simple to deploy applications to your local Kubernetes cluster. Whether you're deploying a single web service or a complex multi-service application, HostK8s provides a consistent pattern that just works.

In this tutorial, you'll create and deploy the classic **Docker Voting App** - a multi-service application that demonstrates how different services work together in Kubernetes.

**What You'll Build:**
- Complete voting application with 5 services
- Python frontend for casting votes
- Redis for vote collection
- .NET worker for vote processing
- PostgreSQL database for storage
- Node.js results dashboard

**What You'll Learn:**
- HostK8s application structure and patterns
- Multi-service application deployment
- Service communication and networking
- Application access patterns (NodePort, Ingress)
- Basic Kubernetes concepts through practical examples
- Foundation concepts for shared components and software stacks

**Prerequisites:**
- **Docker Desktop** v4.0 or later (installed and running)
- **2+ CPU cores, 4GB+ RAM** (8GB recommended)
- **Basic understanding** of web applications and containers
- **Familiarity with HostK8s basics** (see [README](../../README.md))

> **Note:** Required tools (kind, kubectl, helm, flux) are installed automatically via `make install`.

**Resource Expectations:**
- **Startup time:** 2-3 minutes for complete deployment
- **Memory usage:** ~500MB for the voting application (5 services)
- **Storage:** Minimal (database uses ephemeral storage for this tutorial)

## Contents

1. [Understanding HostK8s Building Blocks](#understanding-hostk8s-building-blocks)
2. [Understanding HostK8s Applications](#part-1-understanding-hostk8s-applications)
3. [Creating the Voting Application](#part-2-creating-the-voting-application)
4. [Deploying Your Application](#part-3-deploying-your-application)
5. [Testing Your Application](#part-4-testing-your-application)
6. [Understanding What You Built](#part-5-understanding-what-you-built)
7. [Troubleshooting Common Issues](#part-6-troubleshooting-common-issues)
8. [Next Steps and Advanced Patterns](#part-7-next-steps-and-advanced-patterns)

### Application Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Vote Web App  │    │  Results Web    │    │     Worker      │
│   (Python)      │    │    (Node.js)    │    │    (.NET)       │
│  Port: 8080     │    │  Port: 8081     │    │   (Background)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐                          ┌─────────────────┐
│     Redis       │ ◀────────────────────────│   PostgreSQL    │
│  (Vote Queue)   │                          │   (Results)     │
└─────────────────┘                          └─────────────────┘
```

**User Flow:**
1. **Vote** → User visits voting page (Python app) and casts vote
2. **Queue** → Vote stored in Redis queue
3. **Process** → Worker (.NET) processes vote from queue
4. **Store** → Worker saves vote to PostgreSQL database
5. **Display** → Results page (Node.js) shows live results from database

---

## Understanding HostK8s Building Blocks

Before diving into your first application, let's understand where this tutorial fits in your HostK8s learning journey.

### The Building Blocks Philosophy

Think of HostK8s like **Lego blocks** - you start with individual pieces and progressively learn to build more sophisticated systems:

```
Individual Apps  →  Shared Components  →  Software Stacks
   (Level 100)         (Level 150-200)      (Level 300+)
       │                     │                   │
   This Tutorial      Reusable Services    Complete Environments
```

### Your Learning Journey

**🎯 Level 100 (This Tutorial): Individual Apps**
- See all the building blocks working together
- Understand how services communicate
- Learn HostK8s application patterns
- **Trade-off**: Full visibility but resource duplication

**🔧 Level 150+ (Next Tutorials): Shared Components**
- Reuse infrastructure services across applications
- Resource efficiency through sharing
- **Trade-off**: Less control but much more efficient

**🏗️ Level 300+ (Advanced): Software Stacks**
- Complete development environments
- GitOps automation and orchestration
- **Trade-off**: High abstraction but powerful automation

### Why Start with Individual Apps?

In this tutorial, you'll create a voting application where **each app has its own Redis and database**. This seems wasteful (and it is!), but it's the best way to:

✅ **Understand all the pieces** - See every service and how they connect
✅ **Learn HostK8s patterns** - Application structure, labeling, networking
✅ **Build foundation knowledge** - Concepts you'll use in advanced tutorials
✅ **Recognize the problems** - Understand why shared components and stacks matter

### The Voting App as Your Learning Vehicle

The **Docker Voting App** will be your consistent companion throughout multiple tutorials:
- **Level 100**: Deploy with individual services (this tutorial)
- **Level 150**: Connect to shared Redis component
- **Level 200**: Understand component architecture
- **Level 300**: Deploy via automated stacks

Same app, increasingly sophisticated HostK8s patterns. This consistency lets you focus on learning HostK8s concepts without learning new applications each time.

---

## Part 1: Understanding HostK8s Applications

### What is a HostK8s Application?

A **HostK8s application** is a collection of Kubernetes resources (deployments, services, config maps, etc.) defined in a single YAML file that can be deployed with one command:

```bash
make deploy my-app
```

### Application Structure

Every HostK8s application follows this pattern:

```
software/apps/my-app/
├── README.md          # Documentation
└── app.yaml          # Kubernetes resources
```

**Key Requirements:**
- All resources in one `app.yaml` file
- Resources labeled with `hostk8s.app: my-app`
- Services configured for cluster networking
- Optional NodePort or Ingress for external access

### Simple vs Multi-Service Applications

**Simple Application** (like the built-in `simple` app):
- Single web service
- One deployment, one service
- Static content or simple API

**Multi-Service Application** (like our voting app):
- Multiple connected services
- Database, cache, background workers
- Complex interactions and data flow

### The Extension Pattern

Custom applications go in the `extension/` directory:
```
software/apps/extension/voting-app/
```

This keeps your custom apps separate from built-in HostK8s examples while following the same patterns.

---

## Part 2: Creating the Voting Application

### Step 1: Create Application Directory

Create the directory structure for your voting application:

```bash
mkdir -p software/apps/extension/voting-app
cd software/apps/extension/voting-app
```

### Step 2: Create Application Documentation

Create a `README.md` file to document your application:

```bash
cat > README.md << 'EOF'
# Voting Application

Multi-service voting application demonstrating HostK8s application patterns.

## Architecture
- **Vote**: Python web app for casting votes
- **Redis**: Vote queue and session storage
- **Worker**: .NET service processing votes
- **Database**: PostgreSQL storing results
- **Result**: Node.js web app showing results

## Access
- Vote: http://localhost:8080 (NodePort 30080)
- Results: http://localhost:8081 (NodePort 30081)
- With Ingress: http://localhost/vote and http://localhost/results

## Commands
```bash
# Deploy application
make deploy extension/voting-app

# Check status
kubectl get pods -l hostk8s.app=voting-app

# View logs
kubectl logs -l app=vote
kubectl logs -l app=result
kubectl logs -l app=worker
```
EOF
```

### Step 3: Create Application Manifest

Now create the main `app.yaml` file with all the Kubernetes resources:

```bash
cat > app.yaml << 'EOF'
# Voting Application - Multi-service demo app
# Based on Docker Samples Voting App with pre-built images

# Vote Service (Python Frontend)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vote
  namespace: default
  labels:
    app: vote
    hostk8s.app: voting-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vote
  template:
    metadata:
      labels:
        app: vote
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
  name: vote
  namespace: default
  labels:
    hostk8s.app: voting-app
spec:
  selector:
    app: vote
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort

# Redis (Vote Queue)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: default
  labels:
    app: redis
    hostk8s.app: voting-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: default
  labels:
    hostk8s.app: voting-app
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379

# PostgreSQL Database
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: default
  labels:
    app: db
    hostk8s.app: voting-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
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
  name: db
  namespace: default
  labels:
    hostk8s.app: voting-app
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432

# Worker Service (.NET Background Processor)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: default
  labels:
    app: worker
    hostk8s.app: voting-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
      - name: worker
        image: dockersamples/examplevotingapp_worker
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
  name: result
  namespace: default
  labels:
    app: result
    hostk8s.app: voting-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: result
  template:
    metadata:
      labels:
        app: result
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
  name: result
  namespace: default
  labels:
    hostk8s.app: voting-app
spec:
  selector:
    app: result
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
  type: NodePort

# Ingress (when INGRESS_ENABLED=true)
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: voting-app
  namespace: default
  labels:
    hostk8s.app: voting-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: localhost
    http:
      paths:
      - path: /vote
        pathType: Prefix
        backend:
          service:
            name: vote
            port:
              number: 80
      - path: /results
        pathType: Prefix
        backend:
          service:
            name: result
            port:
              number: 80
EOF
```

### Understanding the Application Manifest

Let's break down what we just created:

**Services Architecture:**
- **Vote** (Python): Web frontend for casting votes → exposed via NodePort 30080
- **Redis**: In-memory store for vote queue → internal service only
- **Worker** (.NET): Background processor → no external access needed
- **Database** (PostgreSQL): Persistent storage → internal service only
- **Result** (Node.js): Results dashboard → exposed via NodePort 30081

**Key Patterns:**
- **Labels**: Every resource has `hostk8s.app: voting-app` for easy management
- **Services**: Internal services use ClusterIP, external services use NodePort
- **Resources**: Memory and CPU limits prevent resource exhaustion
- **Networking**: Services communicate using DNS names (vote → redis, worker → db)
- **Ingress**: Optional path-based routing when ingress controller is available

---

## Part 3: Deploying Your Application

### Step 1: Start Your Cluster

First, ensure you have a running HostK8s cluster:

```bash
# Basic cluster (NodePort access only)
make start

# Or with ingress support for path-based routing
export INGRESS_ENABLED=true
make start
```

### Step 2: Deploy the Voting Application

Deploy your custom voting application:

```bash
make deploy extension/voting-app
```

**What happens:**
- HostK8s reads your `app.yaml` file
- Kubernetes creates all the deployments and services
- Pods start in dependency order (database and redis first)
- Services become available for communication
- NodePort services expose external access

**If deployment fails:**
```bash
# Remove the application using HostK8s command
make remove extension/voting-app

# Then retry deployment
make deploy extension/voting-app
```

### Step 3: Monitor Deployment Progress

Watch your application come online:

```bash
# Check overall cluster status
make status

# View application pods specifically
kubectl get pods -l hostk8s.app=voting-app

# Watch pods start up
kubectl get pods -l hostk8s.app=voting-app -w
```

You should see output like:
```
NAME                      READY   STATUS    RESTARTS   AGE
vote-7d58c54d4b-xyz       1/1     Running   0          30s
redis-6b9b8c7d4f-abc      1/1     Running   0          30s
db-8f7d9c5e2a-def         1/1     Running   0          30s
worker-9e8f7d6c3b-ghi     1/1     Running   0          30s
result-5a6b8c9d7f-jkl     1/1     Running   0          30s
```

### Step 4: Verify Services Are Running

Check that all services are accessible:

```bash
# List services
kubectl get services -l hostk8s.app=voting-app

# Should show:
# vote     NodePort   10.x.x.x   <none>    80:30080/TCP
# result   NodePort   10.x.x.x   <none>    80:30081/TCP
# redis    ClusterIP  10.x.x.x   <none>    6379/TCP
# db       ClusterIP  10.x.x.x   <none>    5432/TCP
```

---

## Part 4: Testing Your Application

### Step 1: Access the Voting Interface

Open the voting application in your browser:

```bash
# Open voting page
open http://localhost:8080
# Or manually visit: http://localhost:8080
```

**What you should see:**
- Clean voting interface with "Cats" vs "Dogs" options
- Click either option to cast your vote
- Page should respond and show vote was recorded

### Step 2: Access the Results Dashboard

Open the results dashboard:

```bash
# Open results page
open http://localhost:8081
# Or manually visit: http://localhost:8081
```

**What you should see:**
- Real-time results chart showing vote counts
- Results update automatically as votes are cast
- Visual representation of current vote totals

### Step 3: Test the Complete Workflow

Test the end-to-end application flow:

1. **Cast Votes**: Go to http://localhost:8080 and vote several times
2. **View Results**: Go to http://localhost:8081 and see votes appear
3. **Multiple Browsers**: Test with different browsers to cast multiple votes
4. **Real-time Updates**: Keep results page open while voting to see live updates

### Step 4: Test with Ingress (if enabled)

If you deployed with `INGRESS_ENABLED=true`:

```bash
# Vote via ingress path
open http://localhost/vote

# Results via ingress path
open http://localhost/results
```

### Validation Checklist

Your voting application is working when:

- **All pods running**: `kubectl get pods -l hostk8s.app=voting-app` shows 5/5 pods Running
- **Vote page loads**: http://localhost:8080 shows voting interface
- **Results page loads**: http://localhost:8081 shows results dashboard
- **Votes register**: Clicking vote options updates the interface
- **Results update**: Vote counts appear on results dashboard
- **Live updates**: Results change in real-time as votes are cast

---

## Part 5: Understanding What You Built

### Service Communication Flow

Let's trace how a vote flows through your application:

```
1. User clicks "Cats" → Vote Service (Python)
2. Vote Service → Stores vote in Redis queue
3. Worker Service → Reads vote from Redis queue
4. Worker Service → Saves vote to PostgreSQL database
5. Result Service → Reads totals from PostgreSQL database
6. Result Service → Displays updated results to user
```

### HostK8s Patterns Demonstrated

Your voting app demonstrates key HostK8s patterns you'll use throughout your learning journey:

**HostK8s Application Pattern:**
- All resources labeled with `hostk8s.app: voting-app` for unified management
- Single `app.yaml` file contains complete application definition
- Consistent naming: services named by function (vote, redis, db, worker, result)

**HostK8s Service Discovery Pattern:**
- Services find each other using standard DNS names
- `vote` connects to `redis` using hostname "redis"
- `worker` connects to both `redis` and `db` by service name
- No complex service mesh or discovery tools needed

**HostK8s Resource Pattern:**
- Development-appropriate CPU and memory limits
- Resource requests ensure reliable scheduling
- Balanced for local development environments

**HostK8s Access Patterns:**
- **Internal services** (redis, db): ClusterIP for service-to-service communication
- **External services** (vote, result): NodePort for direct host access
- **Optional ingress**: Path-based routing when ingress controller available

**HostK8s Extension Pattern:**
- Application lives in `software/apps/extension/` directory
- Follows HostK8s directory structure and naming conventions
- Ready for `make deploy extension/voting-app` command

### Application Architecture Benefits

This multi-service architecture demonstrates:

**Scalability**: Each service can scale independently
```bash
kubectl scale deployment vote --replicas=3
kubectl scale deployment result --replicas=2
```

**Resilience**: If one service fails, others continue running
```bash
kubectl delete pod -l app=vote  # Vote pod restarts automatically
```

**Technology Diversity**: Mix different technologies (Python, .NET, Node.js, Redis, PostgreSQL)

**Microservices**: Each service has a single, focused responsibility

### Understanding Application vs Infrastructure Services

As you examine the voting app architecture, notice that it contains two types of services:

**Application Services** (serve users directly):
- **Vote Service** - Python web app for user voting
- **Result Service** - Node.js dashboard showing results
- **Worker Service** - .NET processor handling vote processing

**Infrastructure Services** (serve other applications):
- **Redis** - In-memory cache for vote queue
- **PostgreSQL** - Database for storing processed results

**Key Insight for Next Steps:**
The infrastructure services (Redis, PostgreSQL) could potentially be **shared** between multiple applications. Instead of each application having its own Redis instance, multiple applications could use a single, well-managed Redis **component**.

### Why This Approach Doesn't Scale

Your voting app works perfectly, but imagine building a real development environment:

**The Problem at Scale:**
```
10 Different Applications × 5 Services Each = 50 Total Services

App 1: vote + redis + worker + db + result
App 2: chat + redis + processor + db + ui
App 3: api + redis + handler + db + admin
... (7 more apps)
```

**Real Resource Impact:**
- **10 Redis instances** using ~640MB total (64MB each)
- **10 PostgreSQL instances** using ~2.5GB total (256MB each)
- **50 total pods** to manage and monitor
- **10 different Redis configurations** to maintain
- **No data sharing** between applications when beneficial

**Management Nightmare:**
- Update Redis version? Do it 10 times
- Change database configuration? 10 different files
- Debug Redis issues? Check 10 different instances
- Resource monitoring? 50 services across 10 namespaces

**The HostK8s Solution Preview:**
```
10 Applications + Shared Components = Efficiency

Shared Components:
├── 1 Redis Infrastructure Component (serves all apps)
├── 1 Database Component (serves all apps)
└── 1 Monitoring Component (watches everything)

Applications:
├── 10 business logic services
└── Connect to shared infrastructure automatically
```

**Benefits You'll Learn:**
✅ **Resource Efficiency**: One Redis serves 10 apps (~64MB vs 640MB)
✅ **Consistent Configuration**: One Redis config, centrally managed
✅ **Shared Data**: Apps can share cache data when beneficial
✅ **Easy Updates**: Update Redis once, all apps benefit
✅ **Centralized Monitoring**: One Redis Commander manages all data

### Honest Trade-offs

**✅ Pros of Individual Apps (This Tutorial)**:
- Complete visibility into every service
- Full control and customization
- Easy to understand and debug
- No dependencies between applications
- Perfect for learning how everything works

**❌ Cons of Individual Apps**:
- Resource waste through duplication
- Management complexity at scale
- Configuration inconsistency
- No data sharing opportunities
- Doesn't prepare you for real environments

**🔮 Next Steps**: Learn HostK8s shared components - reusable infrastructure services that solve these scaling problems while maintaining the development patterns you just learned.

---

## Part 6: Troubleshooting Common Issues

### Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -l hostk8s.app=voting-app
kubectl describe pod <pod-name>
```

**Common issues:**
- Image pull errors (check internet connection)
- Resource constraints (check cluster resources)
- Configuration errors (check environment variables)

### Services Not Accessible

**Check service configuration:**
```bash
kubectl get services -l hostk8s.app=voting-app
kubectl describe service vote
kubectl describe service result
```

**Test internal connectivity:**
```bash
kubectl run test-pod --image=busybox -it --rm -- sh
# From inside pod:
nslookup redis
nslookup db
wget -qO- http://vote
```

### Application Not Working

**Check logs from each service:**
```bash
kubectl logs -l app=vote
kubectl logs -l app=worker
kubectl logs -l app=result
kubectl logs -l app=redis
kubectl logs -l app=db
```

**Common issues:**
- Database connection errors (check db pod status)
- Redis connection errors (check redis pod status)
- Port configuration mismatches

**Reset application if needed:**
```bash
# Remove and redeploy the entire application
make remove extension/voting-app
make deploy extension/voting-app
```

### Access Issues

**NodePort not accessible:**
```bash
# Check Kind port forwarding
docker ps  # Verify Kind container ports
kubectl get nodes -o wide  # Check node IPs
```

**Port forwarding alternative:**
```bash
kubectl port-forward service/vote 8080:80 &
kubectl port-forward service/result 8081:80 &
```

---

## Part 7: Next Steps and Advanced Patterns

### What You Accomplished

**Congratulations!** You've successfully created and deployed your first multi-service HostK8s application:

**Technical Skills Gained:**
- **Multi-service application design** - 5 interconnected services
- **Kubernetes resource management** - Deployments, Services, ConfigMaps
- **Service networking** - Internal communication and external access
- **Application debugging** - Logs, pod status, service connectivity
- **HostK8s patterns** - Extension directory, labeling, deployment commands

**Architecture Understanding:**
- **Microservices communication** - How services find and talk to each other
- **Data flow** - User input → queue → processing → storage → display
- **External access patterns** - NodePort vs Ingress routing
- **Resource management** - CPU/memory requests and limits

### Immediate Next Steps

**Experiment and Learn:**
```bash
# Scale services independently
kubectl scale deployment vote --replicas=3
kubectl scale deployment result --replicas=2

# View real-time logs
kubectl logs -f -l app=worker

# Test resilience
kubectl delete pod -l app=vote
# Watch it automatically restart

# Complete application lifecycle
make remove extension/voting-app  # Remove everything
make deploy extension/voting-app  # Deploy fresh copy
```

**Modify Your Application:**
1. **Change vote options** - Edit OPTION_A and OPTION_B in the vote deployment
2. **Add custom styling** - Mount a ConfigMap with custom CSS
3. **Add monitoring** - Include health check endpoints
4. **Persist data** - Add persistent volumes for the database

### Advanced Application Patterns

**Production Readiness:**
```yaml
# Add health checks
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 30

# Add persistent storage
volumeMounts:
- name: postgres-data
  mountPath: /var/lib/postgresql/data
volumes:
- name: postgres-data
  persistentVolumeClaim:
    claimName: postgres-pvc
```

**Security Enhancements:**
```yaml
# Add secrets for database credentials
env:
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password

# Add network policies
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: voting-app-netpol
```

### Build More Applications

**Try These Next:**
1. **API + Database** - REST API with PostgreSQL backend
2. **Message Queue App** - Producer/consumer pattern with RabbitMQ
3. **Monitoring Stack** - Prometheus + Grafana monitoring setup
4. **CI/CD Pipeline** - GitOps-based deployment automation

**Advanced HostK8s Features:**
- **Custom Software Stacks** - Bundle your app with required infrastructure
- **GitOps Integration** - Automatic deployment from Git repositories
- **Local Registry Workflow** - Build and deploy custom images
- **Extension Development** - Create reusable application templates

### Key Principles Learned

- **Declarative Configuration** - Define desired state, Kubernetes makes it happen
- **Service Discovery** - Services find each other via DNS automatically
- **Resource Management** - Set limits to ensure stable, predictable behavior
- **Label Organization** - Consistent labeling enables powerful filtering and management
- **Progressive Enhancement** - Start simple, add complexity as needed

### Cleanup

When you're finished with the tutorial, remove the voting application:

```bash
# Remove the voting application using HostK8s
make remove extension/voting-app

# Optional: Clean up the cluster entirely
make clean
```

### Additional Resources

- [HostK8s Architecture Guide](../architecture.md) - Deep dive into platform design
- [Shared Components Tutorial](components.md) - Learn to build reusable infrastructure services
- [Software Stacks Tutorial](stacks.md) - Orchestrate complete environments with GitOps
- [Kubernetes Documentation](https://kubernetes.io/docs/) - Official Kubernetes resources
- [Available HostK8s Apps](../../software/apps/) - More application examples

---

**You now understand HostK8s application patterns!** You can create applications ranging from simple web services to complex distributed systems.

**Next Steps in Your Learning Journey:**
- **[Shared Components Tutorial](components.md)** - Learn to build reusable infrastructure services like Redis that multiple applications can share
- **[Software Stacks Tutorial](stacks.md)** - Orchestrate complete environments combining components and applications using GitOps

The same patterns you've learned scale from personal projects to enterprise applications - start simple and add complexity only as needed.
