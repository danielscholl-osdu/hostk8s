---
allowed-tools: Task, mcp__kubernetes__kubectl_get, mcp__kubernetes__kubectl_describe, mcp__flux-operator-mcp__get_flux_instance, mcp__flux-operator-mcp__get_kubernetes_resources, mcp__flux-operator-mcp__get_kubernetes_metrics
argument-hint: [component] [--detailed] | Examples: cert-manager | ingress-nginx --detailed | --quick
description: Comprehensive cluster health assessment with infrastructure and GitOps analysis
model: claude-sonnet-4-20250514
---

# Cluster Health Report

Provide a comprehensive health assessment of the HostK8s cluster with clear role separation and structured output.

## Health Check Modes

**Parse arguments**: `$ARGUMENTS`

### Mode 1: Full Cluster Health (Default)
```bash
/health
```
- Complete infrastructure and software assessment
- Resource efficiency analysis with optimization opportunities
- Development readiness evaluation

### Mode 2: Component-Specific Health
```bash
/health cert-manager
/health ingress-nginx
/health flux-system
```
- **Deep dive into specific component health**
- Detailed resource usage, configuration validation
- Component-specific troubleshooting recommendations

### Mode 3: Quick Status Check
```bash
/health --quick
```
- **Rapid overview** of critical systems only
- Overall status, critical issues, basic resource usage
- Minimal detail for fast status checks

### Mode 4: Detailed Analysis
```bash
/health --detailed
/health cert-manager --detailed
```
- **Extended analysis** with comprehensive metrics
- Historical trends (if available), performance analysis
- Advanced troubleshooting information

## Implementation Strategy

**Use `cluster-agent` to analyze infrastructure:**
- Cluster foundation (nodes, control plane, networking)
- Core Kubernetes components and resource availability
- Infrastructure services (ingress, DNS, storage)
- **Resource usage analysis**: CPU/memory consumption, requests vs limits vs actual usage
- **Resource efficiency**: Over-provisioning identification and optimization opportunities
- **Development capacity**: Available resources for additional workloads
- Any infrastructure-level blocking issues

**Use `software-agent` to analyze GitOps deployment:**
- Flux installation and GitOps pipeline health
- Application deployment status and health
- GitOps reconciliation issues or failures
- Software stack completeness and readiness

## Report Format

**Present results in this structured format:**

1. **Overall Status**: Ready/Warning/Critical with brief explanation
2. **Critical Issues**: Any blocking problems (or "None" if healthy)
3. **Infrastructure Summary**: Node health, resource capacity, core services
4. **Resource Efficiency**:
   - Current CPU/Memory usage vs capacity (percentages)
   - Resource requests vs limits analysis
   - Over-provisioned components with specific optimization opportunities
   - Available headroom for development workloads
   - **Note**: Flux controllers use ~6GB memory limits by default. This is acceptable overhead for GitOps functionality and stability. Focus optimizations on user-deployed components.
5. **Software Summary**: GitOps status, application health, deployment issues
6. **Development Readiness**: What developers can/cannot do right now
7. **Optimization Opportunities**: Specific resource improvements with expected savings
8. **Recommendations**: Priority actions needed (if any)

## Component-Specific Analysis

**When component is specified:**
- **Current Status**: Running/Failed/Pending with details
- **Resource Usage**: Actual vs allocated CPU/memory
- **Configuration Health**: Proper settings, security, networking
- **Dependencies**: Required services and their status
- **Recent Events**: Errors, warnings, or notable changes
- **Optimization Potential**: Component-specific improvement opportunities

## Context and Focus

**Development Laptop Context**: Emphasize resource efficiency and optimization opportunities since HostK8s runs on resource-constrained development environments. Provide specific metrics and recommendations for minimizing resource usage while maintaining capability.

**Actionable Intelligence**: Focus on information that helps developers quickly understand their environment status and any immediate actions needed.

**Resource Management Philosophy Integration**: Acknowledge Flux overhead as acceptable, guide optimization efforts toward user-deployed components.

## Report Output

**Dual Output Strategy:**
1. **Display in Context**: Present the health report directly to the user for immediate visibility
2. **Write to File**: Save the complete health report to the existing data folder as `data/health.md` for persistent storage and reference

**File Format**: Write the report in markdown format with timestamp header:
```markdown
# HostK8s Cluster Health Report
*Generated: YYYY-MM-DD HH:MM:SS*

[Complete health report content here]
```

**Implementation**:
- After compiling the health analysis from both agents
- **FIRST**: Display the complete health report in chat context for immediate user visibility
- **SECOND**: Use the Write tool to save the identical report to `data/health.md`
- Ensure the data directory exists (create if needed)
- Include generation timestamp for tracking report freshness
- **Critical**: The user must see the full report in chat, not just a summary or status

Delegate analysis to appropriate specialist agents, provide structured output based on specified mode, write persistent report to data/health.md, and focus on actionable insights for development environment optimization.
