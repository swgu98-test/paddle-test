
set -e

commit_sha=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_ID" | jq -r '.head.sha')

response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runs?event=pull_request&per_page=100")

if [ "$TARGET_WORKFLOW_NAME" == "all-failed" ]; then
  # Extract all failed run IDs
  run_ids=$(echo "$response" | jq -r '.workflow_runs[] | select(.conclusion == "failure") | .id')
  
  if [ -n "$run_ids" ]; then
    for run_id in $run_ids; do
      echo "Rerunning failed workflow run with ID: $run_id"
      curl -X POST -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$run_id/rerun"
    done
  else
    echo "No failed workflow runs found for PR #$PR_ID."
  fi
else
  # Filter the runs by the PR number and target workflow name
  run_id=$(echo "$response" | jq -r --arg pr_number "$PR_ID" --arg target_workflow "$TARGET_WORKFLOW_NAME" \
    '.workflow_runs[] | select(.head_branch | contains($pr_number) and .name == $target_workflow) | .id' | head -n 1)

  if [ -n "$run_id" ]; then
    echo "Found run_id for PR #$PR_ID with target workflow '$TARGET_WORKFLOW_NAME': $run_id"
    curl -X POST -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$run_id/rerun"
  else
    echo "No matching workflow run found for PR #$PR_ID with target workflow '$TARGET_WORKFLOW_NAME'."
    exit 1
  fi
fi
