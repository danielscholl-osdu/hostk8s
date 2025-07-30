#!/bin/bash
#
# Branch Naming Enforcement Hook for HostK8s
# Enforces gitops/ prefix pattern for new branches
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

# Check for git branch creation commands
branch_name=""

# Match various branch creation patterns
if [[ "$command" =~ git[[:space:]]+checkout[[:space:]]+-b[[:space:]]+([^[:space:]]+) ]]; then
    branch_name="${BASH_REMATCH[1]}"
elif [[ "$command" =~ git[[:space:]]+switch[[:space:]]+-c[[:space:]]+([^[:space:]]+) ]]; then
    branch_name="${BASH_REMATCH[1]}"
elif [[ "$command" =~ git[[:space:]]+branch[[:space:]]+([^[:space:]]+) ]]; then
    branch_name="${BASH_REMATCH[1]}"
fi

# If no branch creation detected, allow command to proceed
if [[ -z "$branch_name" ]]; then
    exit 0
fi

# Allow main branch operations
if [[ "$branch_name" == "main" ]] || [[ "$branch_name" == "master" ]]; then
    exit 0
fi

# Allow existing gitops/ branches
if [[ "$branch_name" =~ ^gitops/ ]]; then
    echo "✅ Branch name follows gitops/ naming convention: $branch_name"
    exit 0
fi

# Block non-compliant branch names
echo "❌ Branch name must use 'gitops/' prefix for GitOps development workflow." >&2
echo "" >&2
echo "❌ Attempted: $branch_name" >&2
echo "✅ Suggested: gitops/$branch_name" >&2
echo "" >&2
echo "Examples of valid branch names:" >&2
echo "  • gitops/add-prometheus-monitoring" >&2
echo "  • gitops/fix-ingress-config" >&2
echo "  • gitops/update-helm-values" >&2
echo "" >&2
echo "This naming convention helps identify GitOps-related changes" >&2
echo "and integrates with automated reconciliation workflows." >&2

exit 2  # Block the tool call
