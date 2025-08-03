---
allowed-tools: Read, Bash(git ls-files:*), Bash(eza:*), Bash(find:*)
argument-hint: [focus-area]
description: Prime Claude with project context and architecture understanding
model: claude-sonnet-4-20250514
---

## Context Discovery

- Project README: @README.md
- Architecture overview: @docs/architecture.md
- All tracked files: !`git ls-files`
- Project structure: !`find . -maxdepth 3 -type f -not -path './.git/*' | head -30`

## Your task

You are now primed with the HostK8s project context. Based on the above information:

1. **Understand the architecture**: This is a Kubernetes development platform built on Kind with host-mode execution
2. **Know the key patterns**: 3-layer abstraction (Make → Scripts → Utilities), GitOps with Flux, extension system
3. **Recognize the structure**:
   - `/infra/` - Kubernetes configs and orchestration
   - `/software/` - GitOps applications and stacks
   - `/src/` - Source code for applications
   - `/docs/` - Architecture documentation

${ARGUMENTS:+## Focus Area

The user wants you to pay special attention to: $ARGUMENTS}

You are now ready to assist with HostK8s development tasks. Use the specialized agents when appropriate:
- `cluster-agent` for infrastructure and Kubernetes issues
- `software-agent` for GitOps and Flux deployments
- `gitops-committer` for any changes requiring Git commits
- `developer-agent` specific autonomous work using a worktree development flow
