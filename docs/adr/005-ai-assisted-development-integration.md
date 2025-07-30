# ADR-005: AI-Assisted Development Integration

## Status
**Accepted** - 2025-07-30

## Context
Modern development platforms benefit from AI assistance to accelerate complex operations, reduce cognitive load, and improve developer productivity. HostK8s, being a GitOps-focused Kubernetes development platform, involves intricate operations across cluster management, GitOps workflows, and debugging scenarios that are ideal candidates for AI enhancement. However, AI assistance must remain optional to preserve the platform's core accessibility and not create dependencies for users who prefer traditional workflows.

## Decision
Integrate **optional AI-assisted development capabilities** through a three-layer architecture: Model Context Protocol (MCP) servers for natural language operations, specialized subagents for domain-specific tasks, and automated hooks for quality assurance. This integration enhances productivity for users who choose to enable it while maintaining full platform functionality for traditional development workflows.

## Rationale
1. **Productivity Multiplier**: AI assistance significantly reduces time for complex GitOps debugging and cluster analysis
2. **Optional Enhancement**: Zero impact on users who prefer traditional workflows
3. **Multi-Tool Compatibility**: Works with Claude Code, GitHub Copilot, and other MCP-enabled AI assistants
4. **Domain Specialization**: Targeted AI agents for specific HostK8s workflows (GitOps, troubleshooting, cluster analysis)
5. **Quality Automation**: Automated enforcement of project standards without manual oversight
6. **Learning Acceleration**: Natural language queries reduce learning curve for complex Kubernetes operations

## Architecture

### Three-Layer AI Assistance Model

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Assistant Layer                       │
│         (Claude Code, GitHub Copilot, etc.)                │
└─────────────────────────────────────────────────────────────┘
                           │
                    MCP Protocol
                           │
                           ▼
┌─────────────────┬───────────────────────────────────────────┐
│   Layer 1:      │           Layer 2:                        │
│   MCP Servers   │           Specialized Subagents           │
│                 │                                           │
│ • kubernetes    │ • hostk8s-analyzer                        │
│ • flux-operator │ • gitops-troubleshooter                   │
│                 │ • gitops-committer                        │
└─────────────────┴───────────────────────────────────────────┘
                           │
                    Layer 3: Automated Hooks
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           Quality Assurance & Automation                    │
│ • Git commit validation                                     │
│ • Branch naming enforcement                                 │
│ • Post-commit GitOps sync                                   │
│ • Pre-commit checks automation                              │
└─────────────────────────────────────────────────────────────┘
```

### Layer 1: MCP Server Integration
- **kubernetes**: Core Kubernetes operations (pods, services, deployments, logs, events)
- **flux-operator-mcp**: GitOps operations (Flux resources, documentation, dependency analysis)
- **Protocol**: Standard MCP interface works with multiple AI assistants
- **Configuration**: `.mcp.json` for Claude Code, `.vscode/mcp.json` for GitHub Copilot

### Layer 2: Specialized Subagents
- **hostk8s-analyzer**: Infrastructure analysis specialist for cluster health and troubleshooting
- **gitops-troubleshooter**: GitOps and Flux specialist for deployment issues and pipeline analysis
- **gitops-committer**: Git workflow specialist for maintaining clean development cycles

### Layer 3: Automated Hooks
- **PreToolUse Hooks**: Git validation, branch naming enforcement
- **PostToolUse Hooks**: Automatic GitOps reconciliation, pre-commit checks
- **Configuration**: `.claude/settings.json` with selective tool matching

## Alternatives Considered

### 1. AI-First Architecture (Rejected)
- **Pros**: Maximum AI integration, cutting-edge developer experience
- **Cons**: Creates AI dependency, excludes users preferring traditional workflows
- **Decision**: Rejected to maintain platform accessibility

### 2. Single AI Assistant Integration (Rejected)
- **Pros**: Simple implementation, single vendor relationship
- **Cons**: Limits user choice, creates vendor lock-in
- **Decision**: Rejected in favor of multi-tool compatibility

### 3. Manual AI Integration Only (Rejected)
- **Pros**: User-controlled AI interaction, no automation
- **Cons**: Misses opportunities for quality automation, higher cognitive load
- **Decision**: Rejected in favor of hybrid manual/automated approach

### 4. ChatOps-Style Integration (Rejected)
- **Pros**: Familiar chat interface, team collaboration
- **Cons**: Requires additional infrastructure, less integrated with development tools
- **Decision**: Rejected in favor of native IDE integration

## Implementation Details

### MCP Server Configuration
```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "npx",
      "args": ["mcp-server-kubernetes"]
    },
    "flux-operator-mcp": {
      "command": "flux-operator-mcp",
      "args": ["serve"],
      "env": {
        "KUBECONFIG": "./data/kubeconfig/config"
      }
    }
  }
}
```

### Subagent Specializations
- **Infrastructure Focus**: Cluster health, node issues, pod troubleshooting
- **GitOps Focus**: Flux resource analysis, deployment debugging, dependency tracing
- **Git Workflow Focus**: Clean commit history, branch management, automated quality

### Hook Integration Points
- **Git Operations**: Automatic validation and professional standards enforcement
- **GitOps Changes**: Automatic Flux reconciliation triggers
- **Quality Gates**: Pre-commit checks run automatically with specialized agents

## Consequences

**Positive:**
- Dramatic productivity improvement for complex debugging and analysis tasks
- Natural language interface reduces learning curve for Kubernetes operations
- Automated quality assurance reduces manual oversight burden
- Multi-tool compatibility preserves user choice in AI assistants
- Optional nature maintains platform accessibility for all users
- Specialized agents provide domain expertise for HostK8s-specific workflows

**Negative:**
- Additional complexity in platform architecture
- Dependency on external AI services for enhanced features
- Learning curve for users adopting AI-assisted workflows
- Potential inconsistency if AI tools produce varying results
- Additional installation requirements for full AI capabilities

**Neutral:**
- Users can adopt AI assistance incrementally (MCP only, then subagents, then hooks)
- Platform remains fully functional without any AI components
- Documentation overhead for explaining AI capabilities and usage patterns

## Success Criteria
- ✅ MCP servers integrate seamlessly with Claude Code and GitHub Copilot
- ✅ Subagents provide accurate, domain-specific assistance for HostK8s workflows
- ✅ Hooks automate quality assurance without interfering with development flow
- ✅ Platform maintains 100% functionality for users not using AI features
- ✅ AI assistance reduces time-to-resolution for complex debugging by 50%+
- ✅ Documentation clearly separates AI-assisted from traditional workflows

## Related ADRs
- [ADR-001: Host-Mode Architecture](001-host-mode-architecture.md) - Foundation platform architecture
- [ADR-003: GitOps Stamp Pattern](003-gitops-stamp-pattern.md) - GitOps workflows enhanced by AI assistance
