#!/bin/bash
set -e

# Check GitHub Actions workflow results
# Usage: ./check-github-workflow.sh [repo] [token] [max_checks]

REPO=${1:-$GITHUB_REPO}
TOKEN=${2:-$GITHUB_TOKEN}
MAX_CHECKS=${3:-20}

if [ -z "$REPO" ] || [ -z "$TOKEN" ]; then
    echo "❌ Missing required parameters"
    echo "Usage: $0 <repo> <token> [max_checks]"
    echo "   or set GITHUB_REPO and GITHUB_TOKEN environment variables"
    exit 1
fi

echo "🔍 Checking GitHub Actions results for: $REPO"
echo "⏱️  Max polling attempts: $MAX_CHECKS"

for i in $(seq 1 $MAX_CHECKS); do
    echo "🔄 Check $i/$MAX_CHECKS - Fetching workflow runs..."
    
    RUNS=$(curl -s -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/$REPO/actions/runs?event=repository_dispatch&per_page=5")
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to fetch workflow runs"
        sleep 30
        continue
    fi
    
    LATEST_RUN=$(echo "$RUNS" | jq -r '.workflow_runs[0] // empty')
    if [ -n "$LATEST_RUN" ] && [ "$LATEST_RUN" != "null" ]; then
        STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
        CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')
        RUN_URL=$(echo "$LATEST_RUN" | jq -r '.html_url')
        RUN_ID=$(echo "$LATEST_RUN" | jq -r '.id')
        
        echo "📊 GitHub Actions Status: $STATUS"
        echo "🔗 Run URL: $RUN_URL"
        echo "🆔 Run ID: $RUN_ID"
        
        if [ "$STATUS" = "completed" ]; then
            echo "✅ GitHub Actions completed with result: $CONCLUSION"
            if [ "$CONCLUSION" = "success" ]; then
                echo "🎉 All comprehensive tests PASSED!"
                exit 0
            else
                echo "❌ Comprehensive tests FAILED!"
                echo "📋 Check details at: $RUN_URL"
                exit 1
            fi
        else
            echo "⏳ Still running ($STATUS)... waiting 30 seconds"
            sleep 30
        fi
    else
        echo "🔍 No recent workflow runs found, waiting..."
        sleep 30
    fi
done

echo "⏰ Timeout waiting for GitHub Actions results after $MAX_CHECKS checks"
echo "🔗 Check manually at: https://github.com/$REPO/actions"
exit 1