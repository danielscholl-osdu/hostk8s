---
description: Gain a general understanding of the code base
---

# Prime

Execute the `Run`, `Read` and `Report` sections to understand the codebase then summarize your understanding.

## Run

git ls-files

## Read

- Project: @README.md
- Architecture overview: @docs/architecture.md
- ADR index: @docs/adr/README.md
- Script Guidance: @infra/scripts/README.md

## Report

Summarize your understanding of the codebase.

1. **Understand the architecture**: This is a Kubernetes development platform built on Kind with host-mode execution
2. **Know the key patterns**: 3-layer abstraction (Make → Scripts → Utilities), GitOps with Flux, extension system
3. **Recognize the structure**:
   - `/infra/` - Kubernetes configs and orchestration
   - `/software/` - GitOps applications and stacks
   - `/src/` - Source code for applications
   - `/docs/` - Architecture documentation
