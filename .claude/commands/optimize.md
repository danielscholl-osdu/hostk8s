# Cluster Resource Optimization

Execute optimization recommendations identified in the health assessment already in context.

**Use `gitops-committer` to implement resource optimizations** through GitOps workflow:

1. **Analyze Health Assessment Context**: Review optimization opportunities from recent health report
2. **Implement Resource Optimizations**: Apply memory/CPU limit reductions for over-provisioned components
3. **Apply Infrastructure Improvements**: Deploy missing components (metrics-server, MetalLB if beneficial)
4. **Validate Changes**: Ensure optimizations maintain functionality while improving efficiency
5. **Commit Optimizations**: Use GitOps workflow to deploy optimized configurations

**Focus Areas for Optimization:**
- **Memory Over-provisioning**: Reduce excessive memory limits on Flux controllers, ingress controllers, and applications
- **CPU Over-provisioning**: Right-size CPU limits based on actual usage patterns
- **Missing Infrastructure**: Deploy metrics-server for monitoring, consider MetalLB for LoadBalancer support
- **Resource Requests/Limits**: Optimize request/limit ratios for better resource utilization

**Target Outcomes:**
- **Memory Recovery**: Free up significant RAM for additional development workloads
- **CPU Efficiency**: Improve CPU allocation and reduce over-commitment
- **Monitoring Enhancement**: Enable real-time resource visibility
- **Development Capacity**: Maximize available resources for application development

**Constraints:**
- Maintain all existing functionality and service availability
- Preserve security and reliability standards
- Follow HostK8s GitOps patterns and conventions
- Test optimizations in development environment first

**Validation Requirements:**
- Verify all pods restart successfully with new resource limits
- Confirm application health and ingress routing remain functional
- Validate resource metrics show improved efficiency
- Ensure GitOps reconciliation continues working properly

Apply optimizations systematically, commit changes through GitOps, and provide before/after resource utilization comparison.
