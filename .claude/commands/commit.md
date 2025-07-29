# Smart Git Commit

I'll analyze your changes, run pre-commit hooks, and create a meaningful commit message.

First, let me check the repository status and detect pre-commit hooks:

```bash
# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    echo "This command requires git version control"
    exit 1
fi

# Detect pre-commit hook setup
HOOKS_AVAILABLE=false
if [ -f .pre-commit-config.yaml ] && command -v pre-commit >/dev/null 2>&1; then
    HOOKS_AVAILABLE=true
    echo "✓ Pre-commit hooks detected"
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

# Run pre-commit hooks BEFORE attempting to commit
if [ "$HOOKS_AVAILABLE" = true ]; then
    echo "Running pre-commit hooks on staged files..."

    # Get list of staged files for hooks
    STAGED_FILES=$(git diff --cached --name-only)

    if [ -n "$STAGED_FILES" ]; then
        # Run pre-commit on staged files
        if ! pre-commit run --files $STAGED_FILES; then
            echo ""
            echo "❌ Pre-commit hooks failed!"
            echo "Common issues in this project:"
            echo "  • YAML syntax errors (check yamllint output above)"
            echo "  • Trailing whitespace (automatically fixed)"
            echo "  • Missing newlines at end of files (automatically fixed)"
            echo "  • Large files or merge conflict markers"
            echo ""
            echo "Files may have been automatically fixed. Check git status and try again."
            echo "To bypass hooks in emergencies: git commit --no-verify"
            exit 1
        fi

        # Re-stage any files that were modified by hooks (formatters, fixers)
        echo "Re-staging any files modified by hooks..."
        git add -u

        echo "✓ All pre-commit hooks passed"
    fi
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

# After successful commit, offer to push to remote
CURRENT_BRANCH=$(git branch --show-current)
REMOTE_EXISTS=$(git remote | head -1)

if [ -n "$REMOTE_EXISTS" ] && [ "$CURRENT_BRANCH" != "HEAD" ]; then
    echo ""
    echo "✓ Commit created successfully on branch: $CURRENT_BRANCH"
    echo ""
    echo "Push to remote repository? (y/N)"
    read -r PUSH_CONFIRM

    if [ "$PUSH_CONFIRM" = "y" ] || [ "$PUSH_CONFIRM" = "Y" ]; then
        echo "Pushing to origin/$CURRENT_BRANCH..."

        if git push origin "$CURRENT_BRANCH"; then
            echo "✓ Successfully pushed to remote"

            # Show helpful next steps for GitLab workflow
            if git remote get-url origin | grep -q gitlab; then
                echo ""
                echo "GitLab workflow options:"
                echo "  • Create merge request: gitlab.com/your-repo/-/merge_requests/new?source_branch=$CURRENT_BRANCH"
                echo "  • View branch: git log --oneline -5"
            fi
        else
            echo "❌ Push failed. You may need to:"
            echo "  • Pull latest changes: git pull origin main"
            echo "  • Resolve conflicts and try again"
            echo "  • Check your authentication credentials"
        fi
    else
        echo "Commit created locally. Push later with: git push origin $CURRENT_BRANCH"
    fi
else
    echo "✓ Commit created successfully"
    if [ -z "$REMOTE_EXISTS" ]; then
        echo "No remote repository configured - commit is local only"
    fi
fi
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

For this HostK8s project, I automatically run comprehensive checks through pre-commit hooks:

- **YAML validation**: Critical yamllint checks for Kubernetes manifests
- **Whitespace cleanup**: Automatic trailing whitespace removal and EOF fixes
- **Syntax validation**: YAML syntax and merge conflict detection
- **File size checks**: Prevents accidentally committing large files
- **Makefile validation**: Ensures Make targets are valid

These validations run automatically before each commit. If any fail, I'll show clear error messages and suggested fixes.

## Error Handling

I'll handle common scenarios gracefully:
- **Pre-commit hook failures**: Show specific errors and fixes (yamllint, whitespace, etc.)
- **Hook file modifications**: Automatically re-stage formatted files
- **Merge conflicts**: Guide through resolution
- **Detached HEAD**: Help return to proper branch
- **No changes**: Explain why commit isn't needed
- **Push failures**: Suggest pull/rebase or credential fixes
- **Network problems**: Advise on offline workflows

## Commit Analysis Enhancement

I'll analyze your changes based on file patterns:
- `infra/` → infrastructure changes
- `software/` → application/deployment changes
- `.gitlab-ci.yml` → CI/CD pipeline changes
- `docs/` → documentation updates
- `Makefile` → build system changes

This ensures accurate commit scopes and types that align with your project structure.
