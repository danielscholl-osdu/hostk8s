# AI Guide

This guide teaches you how to use AI effectively with HostK8s, focusing on proven interaction patterns rather than technical implementation details.

> **Note:** AI technology evolves rapidly. This guide reflects current capabilities as of 2025, but features and availability may change as AI tools mature and expand their HostK8s integration.

## Core Principle

AI in HostK8s is **optional** and designed to accelerate complex operations while preserving traditional workflows. Use AI when it adds value; use standard commands when they're faster.

## AI Technology Integration

HostK8s integrates with popular **primary AI agents** like Claude Code and GitHub Copilot. These AI tools provide the foundation for intelligent assistance in your development workflow.

### Specialized Sub-Agents (Claude Code Only)

Currently, **Claude Code** includes two specialized sub-agents that understand your HostK8s cluster:

- **`cluster-agent`** - Infrastructure specialist for Kubernetes operations (pods, services, nodes, resource usage)
- **`software-agent`** - GitOps specialist for Flux resources (GitRepository, Kustomizations, HelmReleases)

**Important:** These sub-agents are currently exclusive to Claude Code. Other AI tools like GitHub Copilot have basic HostK8s support but don't yet have access to these specialized sub-agents.

Address sub-agents directly by prefixing your questions: `cluster-agent: "your question"` or `software-agent: "your question"`.

### Evolving AI Landscape

AI technology evolves rapidly. While these sub-agents are currently Claude Code-specific, the AI ecosystem may expand to include similar specialized capabilities in other tools as the technology matures.

### Quick Examples

**Cluster Operations:**
```
cluster-agent: "What applications are currently running?"
cluster-agent: "Show me any failing pods and their logs"
cluster-agent: "Which pods are consuming the most resources?"
```

**GitOps Operations:**
```
software-agent: "What's the status of all Flux resources?"
software-agent: "Why isn't my GitRepository reconciling?"
software-agent: "Show me the deployment order of the sample stamp"
```

## Command Prompts - Powerful Shortcuts

HostK8s includes pre-built command prompts (slash commands) that execute complex workflows with a single command.
These are stored in `.claude/commands/` and provide instant access to common operations.

### Available Commands

**`/cluster-health`** - Comprehensive cluster assessment
```
/cluster-health
```
Uses both agents to analyze infrastructure and software deployment status, providing actionable intelligence about your development environment.

**`/commit`** - GitLab workflow assistant
```
/commit "description of changes"
```
Guides you through the complete GitLab workflow: branch creation, conventional commits, merge request creation with proper issue linking.

**`/prime`** - Quick project orientation
```
/prime
```
Rapidly understand project context by reading key documentation and exploring the codebase structure without diving into implementation details.

### Using Command Prompts

Command prompts are more powerful than individual agent questions because they:
- **Execute multi-step workflows** automatically
- **Combine multiple agents** for comprehensive analysis
- **Follow project conventions** (commit formats, branch naming, etc.)
- **Provide structured outputs** with actionable next steps

**Example:**
```
/cluster-health
```
This single command will:
1. Use cluster-agent to check node health, pod status, and resource usage
2. Use software-agent to analyze GitOps resources and dependencies
3. Present a unified report with development readiness assessment

### Creating Custom Commands

You can create your own command prompts by adding markdown files to `.claude/commands/`:

**Example: `.claude/commands/debug-app.md`**
```markdown
# Application Debug Assistant

Analyze the failing application specified in the arguments and provide comprehensive troubleshooting steps.

Use cluster-agent to check pod status, logs, and resource usage.
Use software-agent to verify GitOps deployment status.

Focus on actionable solutions developers can implement immediately.
```

**Usage:**
```
/debug-app sample-app
```

## Quick Start: Your First AI Interaction

**Start your environment:**
```bash
make up sample  # Creates cluster with sample GitOps stamp
```

**Try your first AI interaction** (choose based on your AI tool):

**Option 1: Command prompt** (Claude Code - recommended for beginners):
```
/cluster-health
```

**Option 2: Sub-agent question** (Claude Code only):
```
cluster-agent: "Show me the overall health of my cluster and highlight any issues"
```

**Option 3: GitOps sub-agent** (Claude Code only):
```
software-agent: "Show me the status of all Flux resources in dependency order"
```

**Option 4: Generic AI question** (works with any AI tool):
```
"What's the current status of my Kubernetes cluster?"
```

If any of these work, you have AI assistance running. If not, see [Troubleshooting](#troubleshooting) below.

---

## Effective AI Interaction Patterns

### Pattern 1: The Investigation Ladder
Start broad, then narrow down based on what AI finds.

**Example: Debugging a failing application**

```
1. "What's the overall cluster status?"
   → AI: "3 pods failing in sample namespace"

2. "Focus on the failing pods in sample namespace"
   → AI: "website pod in CrashLoopBackOff, database connection failing"

3. "Show me the website pod logs and network connectivity"
   → AI: "Database service not found, DNS resolution failing"

4. "Check if the database service exists and is healthy"
   → AI: "PostgreSQL pod not ready, init container stuck"
```

**Why this works:** Each query builds on the previous answer, letting AI guide you through the problem systematically.

### Pattern 2: Cross-Context Analysis
Use AI to compare and correlate information across different resources.

**GitOps Resource Relationships:**
```
"Show me the dependency chain from GitRepository to the failing website pod"
```

**Environment Comparisons:**
```
"Compare the sample stamp configuration between this cluster and production"
```

**Resource Usage Patterns:**
```
"Which pods are consuming the most resources and how does that compare to their requests?"
```

**Why this works:** AI can hold multiple contexts in memory and identify patterns humans might miss.

### Pattern 3: Root Cause Analysis
Let AI trace problems back to their source across the entire stack.

**GitOps Pipeline Issues:**
```
"The website isn't accessible. Trace this from the GitOps deployment through to the running pod"
```

**Certificate Problems:**
```
"HTTPS isn't working for my ingress. Check the certificate chain from cert-manager to the ingress controller"
```

**Why this works:** AI can follow complex dependency chains across Kubernetes, GitOps, and networking layers.

### Pattern 4: Documentation and Learning
Use AI as an interactive manual for complex operations.

**Understanding Flux Resources:**
```
"Explain what this Kustomization resource is doing and why it might be failing"
```

**Best Practices:**
```
"What's the recommended way to handle database migrations in this GitOps setup?"
```

**Troubleshooting Guidance:**
```
"I need to update the ingress configuration. Walk me through the GitOps process step by step"
```

---

## When to Use AI vs Traditional Commands

### Use AI When:
- **Complex analysis needed:** software-agent: "Why is my GitOps deployment stuck?" or `/cluster-health`
- **Multiple resources involved:** cluster-agent: "Show me all resources related to the website application"
- **Pattern recognition:** cluster-agent: "Are there any resource issues I should be concerned about?" or `/cluster-health`
- **Learning:** software-agent: "How does this stamp pattern work?" or `/prime`
- **Cross-environment comparison:** software-agent: "What's different between my clusters?"

### Use Traditional Commands When:
- **Simple operations:** `kubectl get pods` (faster than asking AI)
- **Muscle memory tasks:** `make restart` (you know exactly what you want)
- **Debugging AI suggestions:** Verify AI recommendations with direct kubectl
- **Emergency fixes:** When speed matters more than analysis

### Hybrid Approach (Best of Both):
```bash
# Let AI identify the problem
"What pods are failing and why?"

# Use traditional commands to fix it
kubectl delete pod failing-pod
kubectl apply -f fixed-config.yaml

# Let AI verify the fix
"Confirm that the website application is now healthy"
```

---

## GitOps-Specific AI Patterns

### Understanding Stamp Deployments
```
"Analyze the sample stamp and show me the deployment order of components"
"Which GitOps resources are waiting for dependencies?"
"Generate a visual diagram of the stamp architecture"
```

### Flux Troubleshooting
```
"Why isn't my GitRepository reconciling?"
"Show me the status of all Flux resources in dependency order"
"What's preventing the HelmRelease from installing?"
```

### Stamp Evolution
```
"Help me understand what would happen if I add a new component to this stamp"
"Show me how to safely update the database component version"
```

---

## Quality Automation Patterns

When you make commits, AI automatically improves your workflow:

### Commit Message Enhancement
**Before:** `git commit -m "fix stuff"`
**After:** AI automatically improves to: `fix: resolve pod startup issues in sample namespace`

### Branch Naming Enforcement
**Before:** Creating branch `random-fixes`
**After:** AI suggests: `fix/pod-startup-issues` or `feat/add-monitoring`

### GitOps Sync Automation
**Before:** Manual `flux reconcile` after changes
**After:** AI automatically triggers reconciliation when it detects GitOps file changes

**Pro tip:** Let automation handle routine quality tasks while you focus on development.

---

## Advanced AI Interaction Techniques

### Contextual Follow-ups
Once AI understands your environment, ask follow-up questions:

```
Initial: "Analyze cluster health"
Follow-up: "Focus on the networking issues you mentioned"
Follow-up: "Show me the configuration that's causing the DNS problems"
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

### Environment-Aware Queries
Take advantage of AI's context awareness:

```
"Based on my current stamp configuration, what monitoring should I add?"
"Given my resource usage patterns, how should I optimize replica counts?"
"What security improvements would you recommend for this setup?"
```

---

## Common Interaction Mistakes

### ❌ Being Too Vague
**Don't ask:** "Something is broken"
**Instead ask:** "The website pod in the sample namespace isn't starting - what's wrong?"

### ❌ Asking for Impossible Tasks
**Don't ask:** "Fix my cluster" (AI can't make changes for you)
**Instead ask:** "Identify the problems and suggest fixes I can implement"

### ❌ Ignoring Context
**Don't ask:** "How do I deploy an app?" (generic)
**Instead ask:** "How do I add a new application to my sample stamp?"

### ❌ Not Verifying AI Suggestions
Always double-check AI recommendations with `kubectl` commands before applying changes.

---

## Integration with Your Workflow

### IDE Integration
```bash
# AI automatically uses your cluster context
export KUBECONFIG=$(pwd)/data/kubeconfig/config
# Now AI commands work with your active cluster
```

### CI/CD Integration
Use AI insights to improve your pipelines:
```
"Analyze why the CI pipeline is failing on the GitOps validation step"
"What would happen if I deploy this stamp to staging?"
```

### Development Iteration
```bash
make up sample           # Start with stamp
# Quick check: /cluster-health
# Or ask: cluster-agent: "What applications are deployed?"
make restart sample      # Iterate
# Quick check: /cluster-health
# Or ask: cluster-agent: "Confirm everything redeployed correctly"
```

---

## Troubleshooting AI Features

### Quick Diagnostics
```bash
make mcp-status     # Check AI tool connectivity
kubectl get nodes   # Verify cluster access
```

### Common Issues

**"Sub-agents don't respond"** (Claude Code only)
- Check: `make mcp-status` - should show flux-operator-mcp binary found
- Verify: `kubectl get nodes` - cluster should be accessible
- Fix: `make up` if no cluster is running
- Note: Other AI tools don't have access to cluster-agent/software-agent

**"AI can't see my cluster"** (any AI tool)
- Verify: `echo $KUBECONFIG` points to `./data/kubeconfig/config`
- Fix: `make up` to ensure cluster is running
- Try generic questions instead of sub-agent specific ones

**"AI gives outdated information"**
- AI reads real-time cluster state (Claude Code) or may need context refresh (other tools)
- Try: cluster-agent: "Refresh and show me current pod status" (Claude Code)
- Or: "What's the current status of pods in my cluster?" (any AI tool)

**"Wrong response type"** (Claude Code)
- Use explicit sub-agent prefixes: `cluster-agent: "question"` or `software-agent: "question"`
- Or use command prompts: `/cluster-health`, `/prime`, `/commit`
- cluster-agent: for pods, services, nodes, resource usage
- software-agent: for GitOps, Flux resources, stamp analysis

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

1. **Start conversations broadly, then narrow down**
2. **Use AI for analysis, kubectl for action**
3. **Let AI explain complex relationships and dependencies**
4. **Verify AI suggestions before implementing**
5. **Use automation for routine quality tasks**
6. **Combine AI assistance with traditional tools based on the situation**

Remember: AI assistance enhances your Kubernetes expertise but doesn't replace it. Use it as a powerful analytical tool while maintaining hands-on control of your infrastructure.

---

## Related Documentation

- **[Architecture Overview](architecture.md)** - How AI integration fits into HostK8s
- **[ADR-005](adr/005-ai-assisted-development-integration.md)** - Technical decision behind AI integration
- **[README.md](../README.md)** - Core platform capabilities and getting started
