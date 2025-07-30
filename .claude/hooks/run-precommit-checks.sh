#!/bin/bash
#
# Pre-commit Integration Hook for HostK8s
# Runs after gitops-committer subagent operations to ensure code quality
#

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Extract tool name from JSON input
tool_name=$(echo "$input" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

# Only process Task tool calls (subagent operations)
if [[ "$tool_name" != "Task" ]]; then
    exit 0
fi

# Check if this was a gitops-committer subagent call
if ! echo "$input" | grep -q "gitops-committer" 2>/dev/null; then
    exit 0
fi

# Change to project directory
cd "$CLAUDE_PROJECT_DIR" || exit 1

echo "🔍 Running pre-commit checks after gitops-committer operation..."

# Check if pre-commit is installed and configured
if ! command -v pre-commit >/dev/null 2>&1; then
    echo "⚠️  pre-commit not installed. Skipping automated checks."
    echo "Install with: pip install pre-commit && pre-commit install"
    exit 0
fi

if [[ ! -f .pre-commit-config.yaml ]]; then
    echo "ℹ️  No .pre-commit-config.yaml found. Skipping pre-commit checks."
    exit 0
fi

# Run pre-commit on all staged files (if any)
if git diff --cached --quiet; then
    echo "ℹ️  No staged changes found. Skipping pre-commit checks."
    exit 0
fi

echo "🧹 Running pre-commit checks on staged files..."

# Run pre-commit hooks on staged files
if pre-commit run --config .pre-commit-config.yaml 2>&1; then
    echo "✅ Pre-commit checks passed"
else
    echo "🔧 Pre-commit found issues and attempted to fix them."
    echo "📝 Files may have been modified. Review changes before committing."

    # Show what files were modified
    if ! git diff --quiet; then
        echo ""
        echo "📋 Modified files:"
        git diff --name-only | sed 's/^/  • /'
    fi

    # Re-stage automatically fixed files
    if git diff --name-only | grep -q .; then
        echo ""
        echo "🔄 Re-staging automatically fixed files..."
        git add -u
        echo "✅ Fixed files re-staged for commit"
    fi
fi

# Additional YAML validation for GitOps files
echo ""
echo "🔍 Running additional YAML validation..."

# Check if yamllint is available
if command -v yamllint >/dev/null 2>&1; then
    if [[ -f .yamllint.yaml ]]; then
        # Only check staged YAML files
        staged_yaml_files=$(git diff --cached --name-only | grep -E '\.(yaml|yml)$' || true)

        if [[ -n "$staged_yaml_files" ]]; then
            echo "📋 Validating staged YAML files:"
            echo "$staged_yaml_files" | sed 's/^/  • /'

            if echo "$staged_yaml_files" | xargs yamllint -c .yamllint.yaml; then
                echo "✅ YAML validation passed"
            else
                echo "❌ YAML validation failed. Fix issues before committing."
                exit 2  # Block if YAML validation fails
            fi
        else
            echo "ℹ️  No staged YAML files to validate."
        fi
    else
        echo "⚠️  No .yamllint.yaml config found. Skipping YAML validation."
    fi
else
    echo "⚠️  yamllint not installed. Skipping YAML validation."
fi

echo ""
echo "🎉 Pre-commit integration complete. Ready for git commit."

exit 0
