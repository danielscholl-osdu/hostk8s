# Cluster Health Report

Provide a comprehensive health assessment of the HostK8s cluster with clear role separation and structured output.

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

**Present results in this format:**
1. **Overall Status**: Ready/Warning/Critical with brief explanation
2. **Critical Issues**: Any blocking problems (or "None" if healthy)
3. **Infrastructure Summary**: Node health, resource capacity, core services
4. **Resource Efficiency**:
   - Current CPU/Memory usage vs capacity (percentages)
   - Resource requests vs limits analysis
   - Over-provisioned components with specific optimization opportunities
   - Available headroom for development workloads
5. **Software Summary**: GitOps status, application health, deployment issues
6. **Development Readiness**: What developers can/cannot do right now
7. **Optimization Opportunities**: Specific resource improvements with expected savings
8. **Recommendations**: Priority actions needed (if any)

Focus on actionable intelligence that helps developers quickly understand their environment status and any immediate actions needed.

**Development Laptop Context**: Emphasize resource efficiency and optimization opportunities since HostK8s runs on resource-constrained development environments. Provide specific metrics and recommendations for minimizing resource usage while maintaining capability.
