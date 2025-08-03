# Contributing to HostK8s

HostK8s provides automated Kubernetes development environments with GitOps validation.

## Requirements

- **YAML compliance**: All files must pass yamllint validation (see `.yamllint.yaml`)
- **Extension-only changes**: Use `extension/` directories - never modify core platform files
- **Make interface**: All operations through Make commands (`make up`, `make deploy`, etc.)
- **Conventional commits**: Follow standard commit format for automated workflows

See [Architecture Decision Records](docs/adr/README.md) for design rationale.

## Quick Start

```bash
git clone https://community.opengroup.org/danielscholl/hostk8s.git
cd hostk8s
make install  # Installs kind, kubectl, helm, flux (auto-detects platform)
make prepare  # Sets up git hooks and validation
```

**Linux users**: Use `NATIVE_INSTALL=true make install` for native package managers.

**Quality gates**: Pre-commit hooks automatically validate YAML, shell scripts, and commit format.

## Making Changes

### Recommended: AI-Assisted Workflow

```bash
$agent: /commit "description of changes"
```

Automates: issue creation, branch naming, conventional commits, MR creation.

### Manual Workflow

```bash
git checkout -b feature/description
# Make changes
git commit -m "feat(scope): description"
git push origin feature/description
# Create MR via GitLab web UI or: glab mr create
```

**Commit types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`


## Validation

Automated pipelines validate all merge requests:
- YAML formatting and shell script compliance
- Kind cluster deployment and GitOps integration
- Application connectivity testing

Pipeline failures must be resolved before merging.
