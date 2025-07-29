# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

This is **HostK8s** - a host-mode Kubernetes development platform using Kind installed directly on the host system. It eliminates Docker-in-Docker complexity in favor of a stable, lightweight single-node cluster for local development.

**Key Innovation:** GitOps stamp pattern for deploying complete, declarative environments. The "sample" stamp demonstrates the pattern - future stamps (like OSDU-CI) will provide domain-specific environments.

**Key Architectural Decision:** Host-installed tools (kind, kubectl, helm) with Make interface for convenience. All services deployed via Flux GitOps.

## Quick System Validation

Before helping users, run this quick test to verify the Make system is working:

```bash
make help                    # Should show organized command list
make up && make status && make clean  # Optional full test
```

If any command fails, check:
1. Required tools installed (docker, kind, kubectl, helm)
2. Docker Desktop is running
3. Working directory is the project root

## Essential Commands

```bash
# Primary workflow
make up          # Start basic cluster
make up sample   # Start cluster with sample GitOps stamp
make deploy      # Deploy sample application (default: sample/app1)
make status      # Check cluster health (includes GitOps status)
make restart     # Quick development reset
make clean       # Complete cleanup

# Development utilities
make test        # Run validation tests
make logs        # View recent events
make sync        # Force Flux reconciliation
make port-forward SVC=myservice PORT=8080 # Port forward services

# GitOps monitoring
flux get all     # Monitor GitOps deployments
flux logs --follow # Watch GitOps sync logs
```

**Important:** Always use `make` commands instead of calling scripts directly (handles KUBECONFIG, validation).

## Project Structure

### Core Scripts
- `infra/scripts/cluster-up.sh` - Primary cluster creation with dependency validation
- `infra/scripts/cluster-restart.sh` - Fast reset for development iteration
- `infra/scripts/validate-cluster.sh` - Cluster validation
- `infra/scripts/utils.sh` - Development utilities

### Configuration Files
- `Makefile` - Simplified wrapper around dedicated scripts (137 lines, reduced from 424)
- `infra/kubernetes/kind-config*.yaml` - Cluster configurations
- `.env` - Environment variables (METALLB_ENABLED, INGRESS_ENABLED, FLUX_ENABLED, APP_DEPLOY)

### Script Architecture
- `infra/scripts/common.sh` - Shared utilities (logging, validation, kubectl helpers)
- `infra/scripts/install.sh` - Dependency installation (kind, kubectl, helm, flux)
- `infra/scripts/prepare.sh` - Development environment setup (pre-commit, yamllint)
- `infra/scripts/status.sh` - Comprehensive cluster status reporting
- `infra/scripts/deploy.sh` - Application deployment with validation
- `infra/scripts/sync.sh` - Flux reconciliation operations
- `infra/scripts/build.sh` - Docker application build and registry push

### Applications
- `software/apps/sample/app1/` - Basic sample app (NodePort)
- `software/apps/sample/app2/` - Advanced app (MetalLB + Ingress)
- `software/apps/sample/app3/` - Multi-service microservices demo
- `software/stamp/` - GitOps stamp patterns for complete environments

## Development Workflow

### Standard Development
1. `make up` - Start cluster
2. `make deploy sample/app1` (or sample/app2/app3) - Deploy application
3. Access via `http://localhost:8080`
4. `make restart` - Reset for iteration
5. `make clean` - Complete teardown

### GitOps Development (Stamp Pattern)
1. `make up sample` - Start cluster with sample GitOps stamp
2. `make status` - Monitor GitOps resource status (enhanced with Flux info)
3. `make sync` - Force Flux reconciliation if needed
4. `flux get all` - Monitor GitOps deployments
5. `flux logs --follow` - Watch synchronization

### Debugging
- `kubectl run debug --image=busybox --rm -it --restart=Never -- sh` - Debug shell
- `make logs` - View recent cluster events
- `make status` - Comprehensive cluster health check

## Code Quality Requirements

### YAML Validation (CRITICAL)
**ALWAYS validate YAML after any changes** to prevent CI/CD pipeline failures:

```bash
yamllint -c .yamllint.yaml .
```

Common issues that break pipelines:
- Trailing spaces: `sed -i '' 's/[[:space:]]*$//' filename.yml`
- Missing newlines at end of file (ensure exactly one newline at EOF)
- Line length over 200 characters
- Incorrect indentation (2 spaces for Kubernetes YAML)

### CI/CD Pipeline
- **GitLab CI**: Fast validation (~4 minutes) - validates project structure, Makefile syntax, YAML files
- **GitHub Actions**: Comprehensive Kubernetes testing (~8-10 minutes) - full cluster integration tests
- **Pre-commit hooks**: Validate YAML, trailing spaces, newlines

## Architecture Principles

### Host-Mode Benefits
- ✅ Eliminates Docker Desktop hanging issues
- ✅ Faster startup times (< 2 minutes)
- ✅ Lower resource requirements (4GB vs 8GB)
- ✅ Standard kubectl/kind workflow

### Design Philosophy
- **Ephemeral clusters**: Disposable, recreatable in under 2 minutes
- **Single-node simplicity**: No multi-node complexity for development
- **Progressive complexity**: Basic cluster by default, add-ons opt-in
- **Host tool preference**: Use host tools, not containers for core operations
- **Makefile simplicity**: Thin wrapper around dedicated, testable scripts (ADR-002 implementation)

## AI Usage Guidelines

### Use `make` commands for:
- All standard operations (up, down, status, deploy, etc.)
- User-facing recommendations
- KUBECONFIG management

### Use scripts directly for:
- Understanding implementation details
- Debugging Make target issues
- Custom automation scenarios

### Reference README.md for:
- User getting-started information
- Project structure overview
- Basic troubleshooting

## Git Commit Guidelines

**IMPORTANT: Commit Message Format**
- **NEVER include** AI attribution in commit messages
- Write clean, professional commit messages without AI signatures
- Focus on **what changed** and **why** it changed
- Use conventional commit format: `feat:`, `fix:`, `docs:`, etc.
- Keep commit messages concise but descriptive

## Error Handling

The scripts include comprehensive error handling:
- **Dependency validation**: Checks for kind, kubectl, helm, docker
- **Resource validation**: Docker memory/CPU recommendations
- **Retry logic**: Exponential backoff for transient failures
- **Cleanup on failure**: Automatic partial installation cleanup
