#!/bin/bash

# This script takes a jsonl file as input which is the stdout of a Dependabot CLI run.
# It takes the `type: create_pull_request` events and creates a pull request for each of them
# by using git commands.

# Note at this time there is minimal error handling.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <result.json>"
  exit 1
fi

INPUT="$1"

GITLAB_TOKEN="${GITLAB_TOKEN:-}"
if [ -z "$GITLAB_TOKEN" ]; then
  echo "Error: GITLAB_TOKEN environment variable is not set or empty."
  exit 1
fi
GITLAB_REPO="${GITLAB_REPO:-gitlab.com/javiertuya/dashgit-test}"
GITLAB_REPO_URL="https://oauth2:$GITLAB_TOKEN@$GITLAB_REPO"
REPO_DIR="gitlab-repo"

# Clean and clone the GitLab repository into a subdirectory
rm -rf "$REPO_DIR"
git clone "$GITLAB_REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"
ls -la

git config --global user.email "support@gitlab.com"
git config --global user.name "Dependabot Standalone"
git config --global advice.detachedHead false

# Parse each create_pull_request event
jq -c 'select(.type == "create_pull_request")' "../$INPUT" | while read -r event; do
  # Extract fields
  BASE_SHA=$(echo "$event" | jq -r '.data."base-commit-sha"')
  PR_TITLE=$(echo "$event" | jq -r '.data."pr-title"')
  PR_BODY=$(echo "$event" | jq -r '.data."pr-body"')
  COMMIT_MSG=$(echo "$event" | jq -r '.data."commit-message"')
  BRANCH_NAME="dependabot-$(echo -n "$COMMIT_MSG" | sha1sum | awk '{print $1}')"

  echo "Processing PR: $PR_TITLE"
  echo "  Base SHA: $BASE_SHA"
  echo "  Branch: $BRANCH_NAME"

  # Create and checkout new branch from base commit
  git fetch origin
  git checkout "$BASE_SHA"
  git checkout -b "$BRANCH_NAME"

  # Apply file changes
  echo "$event" | jq -c '.data."updated-dependency-files"[]' | while read -r file; do
    FILE_PATH=$(echo "$file" | jq -r '.directory + "/" + .name' | sed 's#^/*##')
    DELETED=$(echo "$file" | jq -r '.deleted')
    if [ "$DELETED" = "true" ]; then
      git rm -f "$FILE_PATH" || true
    else
      mkdir -p "$(dirname "$FILE_PATH")"
      chmod +w "$FILE_PATH" || true
      echo "$file" | jq -r '.content' > "$FILE_PATH"
      git add "$FILE_PATH"
    fi
  done

  # Commit and push
  echo "commiting changes to $BRANCH_NAME"
  git commit -m "$COMMIT_MSG"
  echo "pushing changes to $BRANCH_NAME"
  git push -f origin "$BRANCH_NAME"
  echo "Creating Merge Request for $BRANCH_NAME"

  # Create MR using glab CLI
  echo "***************PR Body: $PR_BODY"
  PR_BODY_ESCAPED="${PR_BODY//</\\<}"
  PR_BODY_ESCAPED="${PR_BODY_ESCAPED//>/\\>}"
  /snap/bin/glab mr create --title "$PR_TITLE" --description "$PR_BODY_ESCAPED" --target-branch main --source-branch "$BRANCH_NAME" --label dependencies || true

  # Return to main branch for next PR
  git checkout main
done

cd ..
