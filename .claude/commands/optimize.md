---
allowed-tools: Task, mcp__kubernetes__kubectl_get, mcp__kubernetes__kubectl_describe, mcp__flux-operator-mcp__get_kubernetes_resources, mcp__flux-operator-mcp__get_kubernetes_metrics
argument-hint: [component] [context] | Examples: cert-manager | ingress-nginx for heavy load | app/my-spring-app for production
description: Optimize cluster resource usage through GitOps
model: claude-sonnet-4-20250514
---

# Cluster Resource Optimization

Optimize cluster resource usage through analysis and GitOps-managed configuration updates.


allowed-tools: Task, mcp__kubernetes__kubectl_get, mcp__kubernetes__kubectl_describe, mcp__flux-operator-mcp__get_kubernetes_resources, mcp__flux-operator-mcp__get_kubernetes_metrics
argument-hint: [component] [context] | Examples: cert-manager | ingress-nginx for heavy load | app/my-spring-app for production
description: Optimize cluster resource usage through GitOps
Cluster Resource Optimization
Optimize cluster resource usage through analysis and GitOps-managed configuration updates.
Required context - CRITICAL FIRST STEP
BEFORE PROCEEDING WITH ANY ANALYSIS:

Check if the file data/health.md exists
If the file does NOT exist:

STOP immediately
Display this exact message: "❌ Health report not found. Please run /health first to generate a baseline health report before optimizing resources."
Do NOT proceed with any optimization analysis


If the file exists:

Read the complete contents of data/health.md
Parse the health analysis data for current resource usage patterns
Use this data as the foundation for optimization decisions



File Check Implementation:
```bash
# Check if health report exists
if [ ! -f "data/health.md" ]; then
    echo "❌ Health report not found. Please run \`/health\` first to generate a baseline health report before optimizing resources."
    exit 1
fi
```

# Read health report
HEALTH_DATA=$(cat data/health.md)

## Optimization Modes

**Parse arguments**: `$ARGUMENTS`

### Mode 1: General System Optimization (No Arguments)
```bash
/optimize
```
- Apply **conservative rule-based optimization** across all user-deployed components
- Use safe multipliers (2x current usage → new limit)
- Skip system components (Flux controllers per resource management philosophy)
- Focus on components manageable through GitOps

### Mode 2: Component-Specific Optimization (Component Specified)
```bash
/optimize cert-manager
/optimize ingress-nginx
/optimize app/my-spring-app
```
- **Detect and analyze the specific component** in the cluster
- Get current resource usage and limits via metrics
- Apply **component-appropriate optimization** based on component type:
  - cert-manager: Lightweight operations, 1.5-2x usage
  - ingress-nginx: Moderate startup overhead, 2x usage
  - Applications: Depends on detected type, default 2x usage

### Mode 3: Context-Aware Optimization (Component + Context)
```bash
/optimize cert-manager for heavy load
/optimize ingress-nginx for development
/optimize app/my-app for production traffic
```
- Use **component analysis** as baseline
- Apply **context-specific multipliers** based on guidance:
  - "heavy load" / "production" → 3x current usage
  - "development" / "testing" → 1.5x current usage
  - "high concurrency" → 2.5x current usage
  - Custom values: "for 512MB memory" → Use specified value

## Implementation Strategy

1. **Read Health Report**: First check for existing `data/health.md` file:
   - If found: Read and parse the health analysis for current resource state
   - If not found: Inform user to run `/health` first to generate baseline report
2. **Analyze Current State**: Use health report data supplemented by MCP tools if needed
3. **Determine Optimization Approach**: Based on arguments, health report findings, and current usage patterns
4. **Calculate Target Resources**: Apply appropriate multipliers and safety margins
5. **Delegate to GitOps**: Use `gitops-committer` to implement changes through software/ directory

**Health Report Integration:**
- Use existing resource efficiency analysis from `data/health.md`
- Leverage identified over-provisioned components and optimization opportunities
- Reference available headroom calculations for target resource planning
- Skip redundant analysis if recent health report available (< 1 hour old)

**Use `gitops-committer` to implement resource optimizations** through GitOps workflow:
- Modify resource limits in component YAML files
- Commit changes with descriptive messages
- Trigger GitOps reconciliation
- Validate deployment success

## Focus Areas for Optimization

**Included Components:**
- **User-Deployed Components**: ingress controllers, applications, databases
- **Stack Components**: cert-manager, monitoring tools, service mesh
- **Add-on Services**: metrics-server, logging, security tools

**Excluded from Optimization:**
- **Flux Controllers**: Default 1GB memory limits per controller (6GB total) are acceptable for stability and GitOps functionality. Optimizing Flux requires custom installation methods that compromise simplicity.

## Target Outcomes

- **Memory Recovery**: Free up RAM for additional development workloads
- **CPU Efficiency**: Improve CPU allocation and reduce over-commitment
- **Right-Sizing**: Match resource limits to actual usage patterns + safety margin
- **Development Capacity**: Maximize available resources while maintaining reliability

## Constraints

- Maintain all existing functionality and service availability
- Preserve security and reliability standards
- Follow HostK8s GitOps patterns and conventions
- Test optimizations in development environment first
- Use conservative multipliers to avoid under-provisioning

## Validation Requirements

- Verify pods restart successfully with new resource limits
- Confirm application health and ingress routing remain functional
- Validate resource metrics show improved efficiency
- Ensure GitOps reconciliation continues working properly

Analyze current resource usage, apply appropriate optimization strategy based on arguments, implement through GitOps, and provide before/after resource utilization comparison.
