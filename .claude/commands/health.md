# Cluster Health Report

Provide a comprehensive health assessment of the HostK8s cluster with clear role separation and structured output.

**Use `cluster-agent` to analyze infrastructure:**
- Cluster foundation (nodes, control plane, networking)
- Core Kubernetes components and resource availability
- Infrastructure services (ingress, DNS, storage)
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
4. **Software Summary**: GitOps status, application health, deployment issues
5. **Development Readiness**: What developers can/cannot do right now
6. **Recommendations**: Priority actions needed (if any)

Focus on actionable intelligence that helps developers quickly understand their environment status and any immediate actions needed.
