
set -e

COMMIT_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_ID" | jq -r '.head.sha')

echo "Commit SHA: $COMMIT_SHA"

response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runs?event=pull_request&per_page=100")

echo "Response: $response"

if [ "$TARGET_WORKFLOW_NAME" == "all-failed" ]; then
  # Extract all failed run IDs for the specific commit
  run_ids=$(echo "$response" | jq -r --arg commit_sha "$COMMIT_SHA" \
    '.workflow_runs[] | select(.head_sha == $commit_sha and .conclusion == "failure") | .id')

  if [ -n "$run_ids" ]; then
    for run_id in $run_ids; do
      echo "Rerunning failed workflow run with ID: $run_id"
      curl -X POST -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$run_id/rerun"
    done
  else
    echo "No failed workflow runs found for commit $COMMIT_SHA."
    exit 1
  fi
else
  # Filter the runs by the commit SHA and target workflow name
  run_id=$(echo "$response" | jq -r --arg commit_sha "$COMMIT_SHA" --arg target_workflow "$TARGET_WORKFLOW_NAME" \
    '.workflow_runs[] | select(.head_sha == $commit_sha and .name == $target_workflow) | .id' | head -n 1)

  if [ -n "$run_id" ]; then
    echo "Found run_id for commit $COMMIT_SHA with target workflow '$TARGET_WORKFLOW_NAME': $run_id"
    curl -X POST -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$run_id/rerun"
  else
    echo "No matching workflow run found for commit $COMMIT_SHA with target workflow '$TARGET_WORKFLOW_NAME'."
    exit 1
  fi
fi
