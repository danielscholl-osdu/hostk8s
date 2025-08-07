# Deploying Apps

## What is a HostK8s Application?

A **HostK8s application** is a collection of Kubernetes resources organized using specific conventions that enable automatic discovery, deployment, and management through simple commands like `make deploy <app>`.

HostK8s uses a **convention-based approach** - the filesystem structure directly maps to deployment commands, making application management predictable and consistent.

```bash
make deploy extension/sample
# ↓ Automatically maps to ↓
software/apps/extension/sample/
```

Think of HostK8s applications like **Lego instruction sheets** - they tell the system exactly what pieces to use and how to put them together. Just as Lego instructions create consistent results every time you follow them, HostK8s applications deploy predictably across any environment.

---

## The Building Blocks Philosophy

HostK8s follows a **Lego blocks** approach - start with individual pieces, then learn to build increasingly sophisticated systems:

```
Individual Apps  →  Shared Components  →  Software Stacks
   (Level 100)         (Level 150-200)      (Level 300+)
       │                     │                   │
   This Tutorial      Reusable Services    Complete Environments
```

**This Tutorial (Level 100):** Learn application patterns with complete visibility into every service. Each application gets its own Redis, database, and infrastructure - wasteful but educational.

**Next Tutorials:** Learn to share infrastructure services across applications for efficiency, then combine everything into automated development environments.

The sample voting app (Python + Redis + PostgreSQL + .NET + Node.js) serves as your consistent learning vehicle across all tutorials - same app, increasingly sophisticated HostK8s patterns.

---

## Application Requirements

For HostK8s to recognize and deploy your application, it must follow specific structural and labeling requirements.

### Required Directory Structure

```
software/apps/extension/<app-name>/
├── kustomization.yaml    # Required: Orchestrates resources
├── <resource-files>.yaml # Kubernetes resource definitions
└── README.md             # Recommended: Documentation
```

### Critical Requirements

**1. Kustomization File**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  labels:
    hostk8s.app: sample    # REQUIRED: Must match directory name
commonLabels:
  hostk8s.app: sample      # REQUIRED: Applied to all resources
```

**2. Name Consistency**
The directory name **must match** the `hostk8s.app` label value:
```
Directory: software/apps/extension/sample/
           ↓
Label: hostk8s.app: sample
       ↓
Commands: make deploy extension/sample
```

**3. Extension Pattern**
Custom applications live in `software/apps/extension/` - treat this as if you cloned an external application repository into the extension directory for HostK8s integration.

---

## Hands-On: Deploy the Sample Application

Let's immediately deploy a real application to see HostK8s patterns in action. The sample voting app at `software/apps/extension/sample/` demonstrates all the requirements you just learned.

### Step 1: Start Your Cluster

```bash
# Start cluster with LoadBalancer and Ingress support
export METALLB_ENABLED=true
export INGRESS_ENABLED=true
make start
```

### Step 2: Deploy the Application

```bash
# Deploy using HostK8s convention-based discovery
make deploy extension/sample
```

**What HostK8s does internally:**
1. **Path Resolution**: Maps `extension/sample` → `software/apps/extension/sample/`
2. **Kustomization Discovery**: Finds and validates `kustomization.yaml`
3. **Label Verification**: Confirms `hostk8s.app: sample` consistency
4. **Resource Application**: Applies all resources with `kubectl apply -k`

### Step 3: Verify Pattern Recognition

```bash
# Check that HostK8s properly labeled and organized everything
kubectl get all -l hostk8s.app=sample

# View the organized structure
kubectl get pods -l hostk8s.app=sample
```

You should see 5 pods running: vote, redis, worker, db, and result - all labeled consistently.

---

## Service Communication Patterns

Now let's understand how services within your application discover and communicate with each other.

### DNS-Based Service Discovery

HostK8s applications use **standard Kubernetes DNS** for service-to-service communication:

```bash
# Test service discovery from inside the cluster
kubectl exec -it deployment/worker -- nslookup redis
kubectl exec -it deployment/worker -- nslookup db

# Test actual connectivity
kubectl exec -it deployment/worker -- nc -zv redis 6379
kubectl exec -it deployment/worker -- nc -zv db 5432
```

Services automatically find each other using DNS names - no IP addresses or complex discovery needed.

### Internal vs External Services

Check your deployed services:

```bash
kubectl get services -l hostk8s.app=sample
```

You'll see the **HostK8s Service Pattern**:
- **Internal services** (redis, db): ClusterIP for service-to-service communication
- **External services** (vote-lb, result-lb): LoadBalancer for user access

**Key Insight:** Infrastructure services (redis, db) have no external access - they only communicate within the application through service DNS names.

---

## Resource Allocation Patterns

Each application gets its own dedicated infrastructure services:

```bash
# Check resource allocation for this application only
kubectl get pods -l hostk8s.app=sample
kubectl top pods -l hostk8s.app=sample
```

### Resource Isolation Benefits

**Complete Isolation:**
- Each application has dedicated Redis (32Mi memory)
- Each application has dedicated PostgreSQL (128Mi memory)
- No resource sharing between applications
- Clean resource ownership and boundaries

**Development Advantages:**
- **Full Control**: Customize Redis/PostgreSQL versions per application
- **No Dependencies**: Application works independently of others
- **Easy Debugging**: Clear resource ownership and boundaries
- **Safe Testing**: Can't break other applications

### Testing Your Application (Optional)

You can verify the application works end-to-end:

```bash
# NodePort access (always available)
open http://localhost:30080  # Voting interface
open http://localhost:30081  # Results interface

# LoadBalancer access (if METALLB_ENABLED=true)
kubectl get svc vote-lb result-lb  # Get external IPs

# Ingress access (if INGRESS_ENABLED=true)
open http://localhost/vote     # Voting interface
open http://localhost/results  # Results interface
```

**Note:** Testing the application functionality is secondary to understanding HostK8s patterns.

## Why Individual Apps Don't Scale

The per-application resource allocation pattern you just learned works perfectly for development and learning, but creates significant problems at scale.

### The Scaling Problem

Imagine you have **10 different applications**, each following this individual pattern:

```
App 1: vote + redis + worker + db + result (5 services)
App 2: api + redis + processor + db + ui (5 services)
App 3: chat + redis + handler + db + admin (5 services)
... (7 more applications)

Total: 50 services across 10 applications
```

### Real Resource Impact

**Memory Waste:**
- **10 Redis instances** × 32Mi = 320Mi total
- **10 PostgreSQL instances** × 128Mi = 1,280Mi total
- **Total overhead**: ~1.6GB just for infrastructure services

**Management Complexity:**
- **10 Redis configurations** to maintain and update
- **10 database schemas** to migrate and backup
- **50 total pods** to monitor and troubleshoot
- **No shared data** when applications need to communicate

### The HostK8s Solution Preview

In the next tutorials, you'll learn HostK8s **shared components** and **software stacks**:

```
# Instead of 10 individual Redis instances:
1 Shared Redis Component → Serves all 10 applications
1 Shared Database Component → Serves all 10 applications
1 Monitoring Component → Watches everything

# Result:
✅ 10x less memory usage
✅ 1x configuration to maintain
✅ Shared data when beneficial
✅ Centralized monitoring and updates
```

## Next Steps in Your Learning Journey

**You Now Understand:**
- How HostK8s applications are structured and discovered
- The convention-based approach to deployment and management
- Service communication patterns within applications
- Resource allocation and isolation strategies
- Why individual applications don't scale efficiently

**Next Learning Steps:**
1. **[Using Components](shared-components.md)** - Learn to consume pre-built infrastructure services instead of duplicating them in each application
2. **[Building Components](components.md)** - Understand how to design reusable infrastructure services that multiple applications can share
3. **[Software Stacks](stacks.md)** - Orchestrate complete development environments with GitOps automation

### Key HostK8s Principles

**Convention Over Configuration:**
- Filesystem structure directly maps to deployment commands
- Consistent labeling enables automatic resource management
- Directory names must match application labels for recognition

**Resource Isolation with Visibility:**
- Each application gets dedicated infrastructure services
- Clear resource ownership and boundaries
- Easy debugging and troubleshooting within application scope

**Scalability Through Abstraction:**
- Individual applications provide learning foundation
- Shared components enable production efficiency
- Software stacks provide complete environment automation

### Cleanup

When you're finished with the tutorial:

```bash
# Remove the sample application
make remove extension/sample

# Optional: Clean up the cluster entirely
make clean
```

---

**You've mastered HostK8s application patterns!** You understand how to structure applications that integrate seamlessly with HostK8s automation while maintaining clear resource boundaries and service communication patterns.

The convention-based approach you've learned forms the foundation for all HostK8s concepts - from individual applications to shared components to complete software stacks.
