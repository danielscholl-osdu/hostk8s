# AI Guide

This guide shows you how to use AI assistance with HostK8s to accelerate development and troubleshooting.

> **Note:** AI technology evolves rapidly. This guide reflects current capabilities as of 2025, but features and availability may change as AI tools mature.

## Core Principle

AI assistance in HostK8s is **optional** and designed to accelerate complex operations while preserving traditional workflows. Use AI when it adds value; use standard commands when they're faster.

## Getting Started with AI

HostK8s works with AI tools like **Claude Code** and **GitHub Copilot**. Claude Code provides the richest experience with specialized knowledge of your cluster and GitOps deployments.

### Start Here: Quick Commands

The fastest way to get AI help is with built-in slash commands:

```
/cluster-health     # Comprehensive cluster assessment
/prime             # Quick project orientation
/commit "message"  # GitLab workflow assistant
```

### Natural Language Questions

Just ask questions naturally - AI automatically understands what you need:

**Cluster Questions:**
```
"What's the current status of my cluster?"
"Show me any failing pods and their logs"
"Which applications are running and are they healthy?"
```

**GitOps Questions:**
```
"What's the status of my Flux deployments?"
"Why isn't my GitRepository reconciling?"
"Show me the deployment order of components"
```

## Quick Start: Your First AI Interaction

**Start your environment:**
```bash
make up sample  # Creates cluster with sample GitOps stack
```

**Try AI assistance:**

**Option 1: Comprehensive health check**
```
/cluster-health
```

**Option 2: Natural language questions**
```
"What's the overall health of my cluster and highlight any issues"
"Show me the status of all deployments"
"Are there any problems I should know about?"
```

If any of these work, you have AI assistance running. If not, see [Troubleshooting](#troubleshooting) below.

---

## Effective AI Interaction Patterns

### Pattern 1: Start Broad, Then Focus
Ask general questions first, then drill down based on what AI finds.

**Example: Debugging a failing application**

```
1. "What's the overall health of my cluster?"
   → "3 pods failing in sample namespace"

2. "Show me details about the failing pods in sample namespace"
   → "website pod in CrashLoopBackOff, database connection failing"

3. "Show me the website pod logs and check network connectivity"
   → "Database service not found, DNS resolution failing"

4. "Check if the database service exists and is healthy"
   → "PostgreSQL pod not ready, init container stuck"
```

**Why this works:** Each question builds on the previous answer, letting AI guide you through the problem systematically.

### Pattern 2: Ask for Connections and Context
AI can analyze relationships between different parts of your system.

**Examples:**
```
"Show me the dependency chain from GitRepository to the failing website pod"
"Which pods are consuming the most resources and how does that compare to their requests?"
"What's the relationship between my ingress configuration and the certificate issues?"
```

**Why this works:** AI can hold multiple contexts in memory and identify patterns you might miss.

### Pattern 3: Root Cause Analysis
Ask AI to trace problems back to their source across the entire stack.

**Examples:**
```
"The website isn't accessible. Trace this from the GitOps deployment through to the running pod"
"HTTPS isn't working for my ingress. Check the certificate chain from cert-manager to the ingress controller"
```

**Why this works:** AI can follow complex dependency chains across Kubernetes, GitOps, and networking layers.

### Pattern 4: Learning and Guidance
Use AI as an interactive guide for complex operations.

**Examples:**
```
"Explain what this Kustomization resource is doing and why it might be failing"
"What's the recommended way to handle database migrations in this GitOps setup?"
"I need to update the ingress configuration. Walk me through the GitOps process step by step"
```

---

## When to Use AI vs Traditional Commands

### Use AI When:
- **Complex analysis needed:** "Why is my GitOps deployment stuck?" or `/cluster-health`
- **Multiple resources involved:** "Show me all resources related to the website application"
- **Pattern recognition:** "Are there any resource issues I should be concerned about?"
- **Learning:** "How does this deployment pattern work?" or `/prime`
- **Cross-environment comparison:** "What's different between my environments?"

### Use Traditional Commands When:
- **Simple operations:** `kubectl get pods` (faster than asking AI)
- **Muscle memory tasks:** `make restart` (you know exactly what you want)
- **Verifying AI suggestions:** Always double-check with `kubectl` before making changes
- **Emergency fixes:** When speed matters more than analysis

### Best Approach: Combine Both

**Development Workflow:**
```bash
# Start environment
make up sample

# AI-enhanced monitoring
/cluster-health
"Show me the status of all deployments"
```

**Troubleshooting Workflow:**
```bash
# Let AI identify the problem
"What pods are failing and why?"

# Use traditional commands to fix it
kubectl delete pod failing-pod
kubectl apply -f fixed-config.yaml

# Let AI verify the fix
"Confirm that the application is now healthy"
```

---

## GitOps-Specific AI Patterns

### Understanding Stack Deployments
```
"Analyze the sample stack and show me the deployment order of components"
"Which GitOps resources are waiting for dependencies?"
"Explain how this stack is structured"
```

### Flux Troubleshooting
```
"Why isn't my GitRepository reconciling?"
"Show me the status of all Flux resources in dependency order"
"What's preventing the HelmRelease from installing?"
```

### Stack Evolution
```
"Help me understand what would happen if I add a new component to this stack"
"Show me how to safely update the database component version"
```

---

## Built-in AI Automation

HostK8s includes helpful automation that runs in the background:

### Commit Message Enhancement
AI automatically improves commit messages:
- **Before:** `git commit -m "fix stuff"`
- **After:** `fix: resolve pod startup issues in sample namespace`

### Branch Naming Guidance
AI suggests proper branch naming:
- **Instead of:** `random-fixes`
- **Suggests:** `fix/pod-startup-issues` or `feat/add-monitoring`

### GitOps Sync Automation
AI automatically triggers Flux reconciliation when it detects GitOps file changes.

**Pro tip:** Let automation handle routine quality tasks while you focus on development.

---

## Advanced Techniques

### Follow-up Questions
Once AI understands your environment, ask follow-up questions:

```
Initial: "Analyze cluster health"
Follow-up: "Focus on the networking issues you mentioned"
Follow-up: "What's the recommended fix for this?"
```

### Multi-Step Problem Solving
Break complex tasks into AI-assisted steps:

```
"I need to add TLS to my application. What are the required steps?"
"Help me check if cert-manager is properly configured"
"Show me how to update the ingress resource for TLS"
"Verify that the certificate was issued correctly"
```

### Context-Aware Questions
Take advantage of AI's understanding of your specific setup:

```
"Based on my current stack configuration, what monitoring should I add?"
"Given my resource usage patterns, how should I optimize replica counts?"
"What security improvements would you recommend for this setup?"
```

---

## Common Mistakes to Avoid

### ❌ Being Too Vague
**Don't ask:** "Something is broken"
**Instead ask:** "The website pod in the sample namespace isn't starting - what's wrong?"

### ❌ Asking AI to Make Changes
**Don't ask:** "Fix my cluster" (AI can't make changes for you)
**Instead ask:** "Identify the problems and suggest fixes I can implement"

### ❌ Ignoring Your Specific Context
**Don't ask:** "How do I deploy an app?" (generic)
**Instead ask:** "How do I add a new application to my sample stack?"

### ✅ Always Verify AI Suggestions
Double-check AI recommendations with `kubectl` commands before applying changes.

---

## Integration with Your Workflow

### Development Iteration
```bash
make up sample           # Start with stack
/cluster-health          # Quick AI check
make restart sample      # Iterate
"Confirm everything redeployed correctly"
```

### CI/CD Integration
Use AI insights to improve your pipelines:
```
"Analyze why the CI pipeline is failing on the GitOps validation step"
"What would happen if I deploy this stack to staging?"
```

---

## Troubleshooting

### Quick Diagnostics
```bash
kubectl get nodes   # Verify cluster is running
/cluster-health     # Test AI connectivity
```

### Common Issues

**"AI doesn't respond to cluster questions"**
- Verify: `kubectl get nodes` - cluster should be accessible
- Fix: `make up` if no cluster is running
- Try: `/cluster-health` to test connectivity

**"AI can't see my cluster"**
- Ensure cluster is running: `make status`
- Try simple questions first: "What pods are running?"

**"AI gives outdated information"**
- AI reads real-time cluster state
- Try: "Refresh and show me current pod status"

**"Automation isn't working"**
- Check: `.claude/settings.json` exists
- Test: Make a simple commit and watch for automatic improvements

### When AI Fails
AI assistance is designed to fail gracefully:
- Traditional `make` commands always work
- Use `kubectl` to verify AI suggestions
- AI will tell you when it can't access something

---

## Best Practices Summary

1. **Start with `/cluster-health` for comprehensive status**
2. **Ask broad questions first, then drill down**
3. **Use AI for analysis, `kubectl` for actions**
4. **Let AI explain complex relationships and dependencies**
5. **Always verify AI suggestions before implementing**
6. **Combine AI assistance with traditional tools based on the situation**

Remember: AI assistance enhances your Kubernetes expertise but doesn't replace it. Use it as a powerful analytical tool while maintaining hands-on control of your infrastructure.

---

## Advanced: Explicit Subagent Usage

For power users, you can explicitly call specialized agents:

**Infrastructure specialist:**
```
cluster-agent: "Show me detailed resource usage and any infrastructure issues"
```

**GitOps specialist:**
```
software-agent: "Analyze the Flux deployment status and dependency chain"
```

However, natural language questions work just as well and are easier to remember.

---

## Related Documentation

- **[Architecture Overview](architecture.md)** - How AI integration fits into HostK8s
- **[ADR-005](adr/005-ai-assisted-development-integration.md)** - Technical decision behind AI integration
- **[README.md](../README.md)** - Core platform capabilities and getting started
