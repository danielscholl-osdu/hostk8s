# Smart Git Commit

I'll analyze your changes and create a meaningful commit message.

First, let me check if this is a git repository and what's changed:

```bash
# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    echo "This command requires git version control"
    exit 1
fi

# Check if we have changes to commit
if ! git diff --cached --quiet || ! git diff --quiet; then
    echo "Changes detected:"
    git status --short
else
    echo "No changes to commit"
    exit 0
fi

# Show detailed changes
git diff --cached --stat
git diff --stat
```

Now I'll analyze the changes to determine:
1. What files were modified
2. The nature of changes (feature, fix, refactor, etc.)
3. The scope/component affected

If the analysis or commit encounters errors:
- I'll explain what went wrong
- Suggest how to resolve it
- Ensure no partial commits occur

```bash
# If nothing is staged, I'll stage modified files (not untracked)
if git diff --cached --quiet; then
    echo "No files staged. Staging modified files..."
    git add -u
fi

# Show what will be committed
git diff --cached --name-status
```

Based on the analysis, I'll create a conventional commit message:
- **Type**: feat|fix|docs|style|refactor|test|chore
- **Scope**: component or area affected (optional)
- **Subject**: clear description in present tense
- **Body**: why the change was made (if needed)

```bash
# I'll create the commit with the analyzed message
# Example: git commit -m "fix(auth): resolve login timeout issue"
```

The commit message will be concise, meaningful, and follow your project's conventions if I can detect them from recent commits.

**Important**: I will NEVER:
- Add "Co-authored-by" or any Claude signatures
- Include "Generated with Claude Code" or similar messages
- Modify git config or user credentials
- Add any AI/assistant attribution to the commit

The commit will use only your existing git user configuration, maintaining full ownership and authenticity of your commits.

## GitLab Workflow Integration

If working on a feature that needs review, I can help create the full GitLab workflow:

```bash
# Check if we're on main branch and need a feature branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "main" ] && [ -n "$FEATURE_NAME" ]; then
    echo "Creating feature branch: feature/$FEATURE_NAME"
    git checkout -b "feature/$FEATURE_NAME"
fi
```

**Branch Naming Conventions**:
- `feature/description` - New features
- `fix/description` - Bug fixes  
- `docs/description` - Documentation updates
- `chore/description` - Maintenance tasks

After committing, I can help with:
- Creating GitLab issues with appropriate labels
- Pushing the branch to origin
- Creating merge requests with proper templates
- Linking commits to issues

## Project-Specific Validations

For this OSDU-CI project, I'll run additional checks:

```bash
# YAML validation (critical for Kubernetes manifests)
if command -v yamllint >/dev/null 2>&1; then
    echo "Running YAML validation..."
    yamllint -c .yamllint.yaml . || echo "YAML validation failed - check files"
fi

# Pre-commit hooks if available
if [ -f .pre-commit-config.yaml ] && command -v pre-commit >/dev/null 2>&1; then
    echo "Running pre-commit hooks..."
    pre-commit run --files $(git diff --cached --name-only)
fi
```

## Error Handling

I'll handle common scenarios gracefully:
- **Merge conflicts**: Guide through resolution
- **Detached HEAD**: Help return to proper branch
- **No changes**: Explain why commit isn't needed
- **Permission issues**: Suggest authentication fixes
- **Network problems**: Advise on offline workflows

## Commit Analysis Enhancement

I'll analyze your changes based on file patterns:
- `infra/` → infrastructure changes
- `software/` → application/deployment changes  
- `.gitlab-ci.yml` → CI/CD pipeline changes
- `docs/` → documentation updates
- `Makefile` → build system changes

This ensures accurate commit scopes and types that align with your project structure.