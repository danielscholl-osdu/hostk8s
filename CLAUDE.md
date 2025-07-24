# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

OSDU-CI is a **host-mode Kubernetes development environment** using Kind installed directly on the host system. It eliminates Docker-in-Docker complexity in favor of a stable, lightweight single-node cluster for local development.

**Key Architectural Decision:** Host-installed tools (kind, kubectl, helm) with Make interface for convenience. Docker Compose only for optional services (registry, monitoring).

## Quick System Validation

Before helping users, run this quick test to verify the Make system is working:

```bash
# Test 1: Verify Make interface is working
make help                    # Should show organized command list

# Test 2: Quick cluster test (optional - only if needed)
make up && make status && make clean
```

**Expected Results:**
- `make help` - Shows categorized commands (Standard Targets, Cluster Operations, Development, Utilities)
- `make up` - Creates cluster in ~30 seconds, shows "Cluster ready!" message
- `make status` - Shows node status and running services
- `make clean` - Cleanup completes without errors

If any command fails, check:
1. Working directory is `/Users/danielscholl/source/osdu-ci`
2. Required tools installed (docker, kind, kubectl, helm)
3. Docker Desktop is running

## Primary Commands for AI

### Essential Commands
```bash
# Primary workflow
make up          # Start cluster (auto-installs dependencies)
make deploy      # Deploy application (default: app1)
make deploy app2 # Deploy advanced app with MetalLB/Ingress
make status      # Check cluster health
make restart     # Quick development reset (< 1 minute)
make clean       # Complete cleanup

# Development utilities
make test        # Run validation tests
make logs        # View recent events
make port-forward SVC=myservice PORT=8080 # Port forward services

# GitOps with Flux (when FLUX_ENABLED=true)
flux get all     # Monitor GitOps deployments
flux logs --follow # Watch GitOps sync logs
```

### When to Use Scripts vs Make
- **Use Make**: Default choice for all operations (handles KUBECONFIG, validation)
- **Use scripts directly**: Only when debugging Make targets or in automation containers

### Important File Patterns

**Core Scripts (AI should understand these):**
- `infra/scripts/cluster-up.sh` - **Primary cluster creation** with dependency validation
- `infra/scripts/cluster-down.sh` - Clean cluster shutdown
- `infra/scripts/cluster-restart.sh` - Fast reset for development iteration
- `infra/scripts/validate-cluster.sh` - Cluster validation (use --simple for basic tests)
- `infra/scripts/utils.sh` - Development utilities (status, logs, port forwarding)
- `infra/scripts/setup-flux.sh` - Flux GitOps setup (requires flux CLI via `make install`)

**Make Interface:**
- `Makefile` - Standard conventions wrapper around scripts
- Automatic KUBECONFIG management 
- Grouped help sections for discoverability

**Configuration:**
- `infra/kubernetes/kind-config-minimal.yaml` - Minimal cluster config
- `infra/kubernetes/kind-config.yaml` - Standard cluster config  
- `.env` - Environment variables (cluster name, versions, add-on toggles: METALLB_ENABLED, INGRESS_ENABLED, FLUX_ENABLED, APP_DEPLOY)
- `docker-compose.yml` - **Optional services only** (registry, monitoring)

### Development Patterns

**Cluster Lifecycle:**
1. `make up` - Start cluster (includes dependency check)
2. `make deploy` - Deploy sample application
3. `make restart` - Quick reset for development iteration
4. `make clean` - Complete teardown

**Development Workflow:**
1. `make status` - Check cluster health and services
2. `make deploy app1` - Deploy basic sample application  
3. `make deploy app2` - Deploy advanced app (requires MetalLB/Ingress)
4. `make deploy app3` - Deploy multi-service app (microservices demo)
5. `make test` - Run validation tests
6. `make logs` - View recent cluster events
7. `kubectl run debug --image=busybox --rm -it --restart=Never -- sh` - Debug shell
8. Manual kubectl (KUBECONFIG auto-set by Make)

**GitOps Workflow (when FLUX_ENABLED=true):**
1. `kubectl apply -f software/stamp/sources/` - Apply Git/Helm repositories
2. `kubectl apply -f software/stamp/apps/` - Apply application deployments
3. `flux get all` - Monitor GitOps resource status
4. `flux logs --follow` - Watch synchronization logs

**Access Points:**
- **Kubernetes API**: `https://localhost:6443`
- **NodePort Services**: `http://localhost:8080` (mapped from 30080)
- **LoadBalancer**: External IPs when MetalLB enabled
- **Optional Registry**: `localhost:5000`

### Error Handling Context

The scripts include comprehensive error handling:
- **Dependency validation**: Checks for kind, kubectl, helm, docker
- **Resource validation**: Docker memory/CPU recommendations
- **Retry logic**: Exponential backoff for transient failures
- **Cleanup on failure**: Automatic partial installation cleanup
- **Environment detection**: Scripts adapt to host-mode vs container execution

### Key Architecture Points

**Host-Mode Benefits (vs Docker-in-Docker):**
- ✅ Eliminates Docker Desktop hanging issues
- ✅ Faster startup times (< 2 minutes)
- ✅ Lower resource requirements (4GB vs 8GB)
- ✅ Standard kubectl/kind workflow
- ✅ Cross-platform stability

**Design Principles:**
- **Ephemeral clusters**: Disposable, recreatable in under 2 minutes
- **Single-node simplicity**: No multi-node complexity for development
- **Progressive complexity**: Basic cluster by default, add-ons opt-in
- **Host tool preference**: Use host tools, not containers for core operations

### Migration Notes

This repository **was** Docker-in-Docker but has been transformed to host-mode:
- **Old approach (deprecated)**: `docker compose up` with automation container
- **New approach (current)**: `make up` with host tools

If you see references to automation containers or `osdu-automation`, these are legacy and should be updated to host-mode patterns.

### When AI Should Use Different Approaches

**Use `make` commands for:**
- All standard operations (up, down, status, deploy, etc.)
- User-facing recommendations
- KUBECONFIG management

**Use scripts directly for:**
- Understanding implementation details
- Debugging Make target issues
- Custom automation scenarios

**Reference README.md for:**
- User getting-started information
- Project structure overview
- Basic troubleshooting

### Examples and Testing

**Structured Applications:**
- `software/apps/app1/` - Basic sample app (NodePort, 2 replicas)
- `software/apps/app2/` - Advanced sample app (MetalLB + Ingress, 3 replicas)
- `software/apps/app3/` - Multi-service app (3-tier microservices, 5 replicas)
- Deploy with: `make deploy app1`, `make deploy app2`, or `make deploy app3`
- Access: `http://localhost:8080`

**GitOps Examples:**
- `software/stamp/` - Complete Flux GitOps workflow examples
- `software/stamp/sources/` - GitRepository and HelmRepository sources
- `software/stamp/apps/` - Application deployment patterns via GitOps
- `software/stamp/clusters/` - Multi-environment GitOps structures
- Enable with: `FLUX_ENABLED=true make up`
- Deploy examples: `kubectl apply -f software/stamp/sources/`

**Validation Scripts:**
- Use `make test` for cluster validation (runs `validate-cluster.sh --simple`)
- For comprehensive validation: `./infra/scripts/validate-cluster.sh` (full mode)