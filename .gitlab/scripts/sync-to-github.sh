#!/bin/sh
set -e

echo "Syncing code to GitHub repository..."

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Missing GITHUB_TOKEN"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "Missing GITHUB_REPO"
    exit 1
fi

echo "Configuring git..."
git config --global user.email "ci@gitlab.com"
git config --global user.name "GitLab CI"

echo "Encoding token and adding remote..."
GITHUB_ENCODED_TOKEN=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$GITHUB_TOKEN")

git remote add github https://$GITHUB_ENCODED_TOKEN@github.com/$GITHUB_REPO.git || git remote set-url github https://$GITHUB_ENCODED_TOKEN@github.com/$GITHUB_REPO.git

git remote -v

echo "Pushing to GitHub..."
# Push current branch to same branch name on GitHub
# For main branch: pushes to main
# For PR branches: pushes to the PR branch name
CURRENT_BRANCH=${CI_COMMIT_REF_NAME:-main}
echo "Pushing branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "Main branch detected - pushing to main"
    git push github HEAD:main --force
else
    echo "PR branch detected - pushing to branch: $CURRENT_BRANCH"
    git push github HEAD:$CURRENT_BRANCH --force
fi

echo "Code synced successfully to $GITHUB_REPO (branch: $CURRENT_BRANCH)"
