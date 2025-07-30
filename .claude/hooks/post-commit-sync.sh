#!/bin/bash
#
# Post-Commit Flux Sync Hook for HostK8s
# Automatically triggers Flux reconciliation after GitOps commits
#

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Extract tool name and command from JSON input
tool_name=$(echo "$input" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
command=$(echo "$input" | grep -o '"command":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

# Only process Bash tool calls
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

# Only process successful git commit commands
if [[ ! "$command" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

# Change to project directory to ensure git commands work
cd "$CLAUDE_PROJECT_DIR" || exit 1

# Check if the commit actually succeeded by looking at git status
if ! git diff --quiet --cached 2>/dev/null; then
    # Still have staged changes, commit likely failed
    exit 0
fi

# Check if GitOps-related files were in the last commit
gitops_files_changed=false

# Check for YAML files in the last commit
if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E '\.(yaml|yml)$' >/dev/null; then
    gitops_files_changed=true
fi

# Check for stamp directory changes
if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E 'software/stamp/' >/dev/null; then
    gitops_files_changed=true
fi

# Check for Flux-specific directories
if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -E '(flux-system|kustomization|helmrelease)' >/dev/null; then
    gitops_files_changed=true
fi

# Only trigger sync if GitOps files were changed
if [[ "$gitops_files_changed" == "true" ]]; then
    echo "🔄 GitOps files committed, triggering Flux reconciliation..."

    # Check if cluster is running before attempting sync
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "⚠️  Cluster not accessible. Run 'make up' to start cluster, then 'make sync' manually."
        exit 0
    fi

    # Check if Flux is installed
    if ! kubectl get namespace flux-system >/dev/null 2>&1; then
        echo "⚠️  Flux not installed in cluster. GitOps changes committed but not synced."
        exit 0
    fi

    # Trigger Flux reconciliation
    if make sync 2>/dev/null; then
        echo "✅ Flux reconciliation triggered successfully"

        # Provide quick status feedback
        echo "📊 Quick status check:"
        make status 2>/dev/null | grep -E "(Kustomization|HelmRelease|GitRepository)" | head -5 || true
    else
        echo "⚠️  Failed to trigger Flux sync. Run 'make sync' manually to reconcile changes."
    fi
else
    echo "ℹ️  Non-GitOps files committed. No Flux reconciliation needed."
fi

exit 0
