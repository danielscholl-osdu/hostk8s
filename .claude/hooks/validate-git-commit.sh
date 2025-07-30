#!/bin/bash
#
# Git Commit Validation Hook for HostK8s
# Validates git commit commands to ensure professional commit standards
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

# Only process git commit commands
if [[ ! "$command" =~ git[[:space:]]+commit ]]; then
    exit 0
fi

# Extract commit message from various git commit formats
commit_msg=""
if [[ "$command" =~ -m[[:space:]]+[\"\'](.*)[\"\''] ]]; then
    commit_msg="${BASH_REMATCH[1]}"
elif [[ "$command" =~ -m[[:space:]]+([^[:space:]]+) ]]; then
    commit_msg="${BASH_REMATCH[1]}"
fi

# Skip validation if no commit message found (might be using editor)
if [[ -z "$commit_msg" ]]; then
    exit 0
fi

# Check for AI attribution (case insensitive)
if [[ "$commit_msg" =~ [Gg]enerated|[Cc]laude|[Aa][Ii][[:space:]]|[Aa]ssistant|🤖 ]]; then
    echo "❌ Commit message contains AI attribution." >&2
    echo "Professional commit messages should focus on what changed and why." >&2
    echo "Example: 'feat: add GitOps hooks for automated validation'" >&2
    exit 2  # Block the tool call
fi

# Check for secrets or sensitive information
if [[ "$commit_msg" =~ [Pp]assword|[Ss]ecret|[Kk]ey|[Tt]oken|[Aa]pi[_-]?[Kk]ey ]]; then
    echo "⚠️  Commit message may contain sensitive information." >&2
    echo "Consider using more generic terms in commit messages." >&2
    exit 2
fi

# Validate conventional commit format (warning, not blocking)
if [[ ! "$commit_msg" =~ ^(feat|fix|docs|refactor|chore|style|test|perf|build|ci):[[:space:]] ]]; then
    echo "💡 Consider using conventional commit format:" >&2
    echo "   feat: new feature" >&2
    echo "   fix: bug fix" >&2
    echo "   docs: documentation" >&2
    echo "   refactor: code refactoring" >&2
    echo "   chore: maintenance" >&2
    # Don't block, just warn
fi

# Check commit message length (title should be under 72 characters)
title_line=$(echo "$commit_msg" | head -n1)
if [[ ${#title_line} -gt 72 ]]; then
    echo "⚠️  Commit title is ${#title_line} characters (recommend <72)." >&2
    echo "Consider shortening the first line of your commit message." >&2
    # Don't block, just warn
fi

# Success - allow commit to proceed
exit 0
