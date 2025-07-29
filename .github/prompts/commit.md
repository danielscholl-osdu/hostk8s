# Smart Git Commit

For comprehensive project guidance, **READ THE CLAUDE.md FILE** in the root directory first.

Analyze changes and create meaningful commit messages following the project's GitLab workflow.

## Quick Analysis

```bash
# Verify repository state
git status --short
git diff --cached --stat
```

## Commit Process

1. **Stage modified files** if needed: `git add -u`
2. **Analyze changes** by file patterns (see CLAUDE.md for project structure)
3. **Create conventional commit**: type(scope): description
4. **Validate YAML** if any .yaml/.yml files changed: `yamllint -c .yamllint.yaml .`
5. **Run pre-commit hooks** if available

## Project-Specific Scopes

Based on file patterns (detailed in CLAUDE.md):
- `infra/` → infrastructure changes
- `software/` → application/deployment changes  
- `.gitlab-ci.yml` → CI/CD pipeline changes
- `docs/` → documentation updates
- `Makefile` → build system changes

## Important

- **Never include AI attribution** in commit messages
- **Use existing git user configuration** 
- **Follow GitLab workflow** (feature branches, merge requests)
- **Validate YAML files** before committing (critical for CI/CD)