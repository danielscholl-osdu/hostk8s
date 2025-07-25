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

echo "Pushing to GitHub (force)..."
git push github HEAD:main --force

echo "Code synced successfully to $GITHUB_REPO"