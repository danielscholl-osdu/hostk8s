# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

HostK8s is a lightweight Kubernetes development platform built on Kind that combines host-mode architecture with GitOps software stacks for reproducible, efficient development workflows. It addresses common pain points like manual environment setup, environment drift, and heavy tooling overhead.

## Essential SubAgents
- `cluster-agent` - Infrastructure Kubernetes specialist for HostK8s clusters.
- `software-agent` - GitOps/Flux Software specialist for HostK8s clusters.

## Essential Commands

### Cluster Lifecycle
- `make help` - Show all available commands
- `make install` - Install required dependencies (kind, kubectl, helm, flux, flux-operator-mcp)
- `make up` - Start basic cluster
- `make up sample` - Start cluster with software stack (requires `FLUX_ENABLED=true`)
- `make down` - Stop cluster (preserves data)
- `make restart` - Quick cluster reset for development iteration
- `make restart sample` - Restart with software stack
- `make clean` - Complete cleanup (destroy cluster and data)
- `make status` - Show cluster health and running services

### Development Operations
- `make deploy` - Deploy default app (sample/app1)
- `make deploy sample/app2` - Deploy specific application
- `make test` - Run comprehensive cluster validation tests
- `make logs` - View recent cluster events and logs
- `make port-forward SVC=myservice PORT=8080` - Port forward a service
- `make sync` - Force Flux reconciliation (GitOps environments)

### Build and Source Operations
- `make build src/APP_NAME` - Build and push application from src/ directory

### AI-Assisted Operations
- `make mcp-status` - Check MCP server status and connectivity

**Important:** Always use `make` commands instead of calling scripts directly (handles KUBECONFIG, validation).

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

## Git Commit Guidelines

**IMPORTANT: Commit Message Format** (Automatically Enforced)
- **NEVER include** AI attribution in commit messages
- Write clean, professional commit messages without AI signatures
- Focus on **what changed** and **why** it changed
- Use conventional commit format: `feat:`, `fix:`, `docs:`, etc.
- Keep commit messages concise but descriptive

## Quality Assurance

HostK8s includes automatic quality assurance and GitOps integration through Claude Code hooks:
- Git operations have automatic validation and professional standards enforcement
- GitOps file changes trigger automatic Flux reconciliation
- Pre-commit checks run automatically with gitops-committer subagent

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

## High-Level Architecture

### Core Concepts

**Host-Mode Architecture**: Uses Kind directly on host Docker daemon, eliminating Docker-in-Docker complexity for better stability and performance (4GB RAM vs 8GB typical).

**Software Stacks**: Pre-configured complete development environments (infrastructure + applications) deployed as code. Applied via GitOps to keep environments version-controlled and consistent.

### Key Components

**Infrastructure Layer** (`infra/`):
- `infra/scripts/` - All operational scripts for cluster lifecycle, utilities, and component setup
- `infra/kubernetes/` - Kind configuration files (minimal, simple, default)

**Software Layer** (`software/`):
- `software/apps/` - Individual applications (sample/app1, app2, app3, registry-demo)
- `software/components/` - Flux-managed infrastructure components (certs, registry, ingress)
- `software/stack/` - Software stack templates for complete environments

**Source Code** (`src/`):
- Application source code for building and deploying custom applications

### Software Stack Pattern

The software stack pattern deploys complete environments:

1. **Bootstrap Kustomization** (`software/stack/bootstrap.yaml`) - Entry point
2. **Stack Kustomization** (e.g., `software/stack/sample/kustomization.yaml`) - Defines resources
3. **Components** - Infrastructure services (database, ingress-nginx) via Helm
4. **Applications** - Application manifests managed through GitOps

### Network Architecture

- API Server: `localhost:6443`
- NodePort Services: `localhost:8080` (mapped from 30080)
- Optional services when enabled:
  - Container Registry: `localhost:5000`
  - Prometheus: `localhost:9090`

## Development Workflows

### Manual Development
```bash
make up                    # Start basic cluster
make deploy sample/app1    # Deploy basic app
make deploy sample/app2    # Deploy advanced app (needs MetalLB/Ingress)
make status                # Check status
make restart               # Reset for iteration
```

### GitOps Development
```bash
export FLUX_ENABLED=true
make up sample            # Start with complete GitOps environment
make status               # Monitor GitOps reconciliation
make sync                 # Force reconciliation
make restart sample       # Reset with stack
```

## Configuration

### Environment Variables (.env)
Copy `.env.example` to `.env` and customize:

- `LOG_LEVEL` - debug, info, warn, error (default: debug)
- `CLUSTER_NAME` - Cluster name (default: hostk8s)
- `K8S_VERSION` - Kubernetes version (default: latest)
- `KIND_CONFIG` - minimal, simple, default
- `FLUX_ENABLED` - Enable GitOps (default: false)
- `METALLB_ENABLED` - LoadBalancer support (default: false)
- `INGRESS_ENABLED` - NGINX Ingress (default: false)
- `GITOPS_REPO` - Git repository URL for Flux sync
- `GITOPS_BRANCH` - Git branch (default: main)
- `GITOPS_STACK` - Software stack to deploy (sample, sample-stack)

### KUBECONFIG Management
The platform automatically manages KUBECONFIG:
- Location: `./data/kubeconfig/config`
- Automatically set by Make targets
- Compatible with kubectl, helm, flux commands

## AI-Assisted Operations

### MCP Integration
The platform includes dual MCP servers for comprehensive AI assistance:

**Kubernetes MCP Server**: Core Kubernetes operations (pods, services, deployments, logs, events)
**Flux Operator MCP Server**: GitOps operations (Flux resources, documentation search, dependency analysis)

Configuration files:
- `.mcp.json` - Claude Code MCP configuration
- `.vscode/mcp.json` - GitHub Copilot MCP configuration (if present)

### AI Capabilities
- Natural language cluster management and troubleshooting
- AI-powered Flux resource analysis and deployment debugging
- Cross-cluster management and comparison
- Root cause analysis with dependency tracing
- Visual diagrams of infrastructure and GitOps dependencies

## Testing and Validation

### Test Strategy
- `make test` runs comprehensive cluster validation
- Validates cluster health, node status, networking, and service accessibility
- Supports both basic cluster and GitOps stack configurations

### CI/CD Integration
- Hybrid CI/CD strategy using GitLab CI (fast validation) + GitHub Actions (comprehensive testing)
- Branch-aware testing with different cluster configurations
- Automatic YAML validation and make command testing

## File Structure Patterns

### Application Structure
Each app in `software/apps/` follows the pattern:
```
app-name/
├── README.md          # Application documentation
└── app.yaml          # Kubernetes manifests
```

### Stack Structure
Each stack in `software/stack/` follows the pattern:
```
stack-name/
├── README.md          # Stack documentation
├── kustomization.yaml # Stack entry point
├── repository.yaml    # GitRepository source
├── stack.yaml         # Component deployments
├── components/        # Infrastructure Helm releases
└── applications/      # Application manifests
```

### Script Conventions
All operational scripts in `infra/scripts/` source `common.sh` for:
- Consistent logging functions (log_debug, log_info, log_warn, log_error)
- Color formatting and error handling
- Environment variable management

## Important Notes

### Prerequisites
- Docker Desktop v24+
- 2+ CPU cores, 4GB+ RAM (8GB recommended)
- Mac, Linux, or Windows WSL2

### Kind Configurations
- `minimal` - Lightweight for basic testing
- `simple` - Basic development cluster
- `default` - Full-featured development cluster (recommended)

### Dependencies
Required tools installed via `make install`:
- kind - Kubernetes cluster creation
- kubectl - Kubernetes API interaction
- helm - Package management
- flux - GitOps operator
- flux-operator-mcp - AI-assisted GitOps operations

### Performance Characteristics
- Cluster creation: < 2 minutes
- Cluster destruction: < 30 seconds
- Development reset: < 1 minute
- Application deployment: < 30 seconds

### GitOps Best Practices
- Use stacks for complete environments rather than individual apps
- Monitor Flux reconciliation with `make status` and `flux get all`
- Force reconciliation with `make sync` when needed
- Leverage AI assistance through MCP servers for troubleshooting
