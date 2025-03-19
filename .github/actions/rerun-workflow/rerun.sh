
set -e

COMMIT_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_ID" | jq -r '.head.sha')

echo "Commit SHA: $COMMIT_SHA"

response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runs?head_sha=$COMMIT_SHA&per_page=100")

echo "Response: $response"

run_ids=$(echo "$response" | jq -r '.workflow_runs[].id')

if [ -n "$run_ids" ]; then
  echo "Found run_ids for commit $COMMIT_SHA: $run_ids"

  for run_id in $run_ids; do
    jobs_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
      "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$run_id/jobs")

    echo "Jobs Response for run_id $run_id: $jobs_response"

    if [ "$JOB_NAME" = "all-failed" ]; then
      failed_jobs=$(echo "$jobs_response" | jq -r '.jobs[] | select(.conclusion != "success") | .id')
    else
      failed_jobs=$(echo "$jobs_response" | jq -r --arg job_name "$JOB_NAME" \
        '.jobs[] | select(.name == $job_name and .conclusion == "failure") | .id')
    fi

    if [ -n "$failed_jobs" ]; then
      echo "Found failed jobs for run_id $run_id: $failed_jobs"

      for job_id in $failed_jobs; do
        echo "Rerunning job_id: $job_id"
        curl -X POST -H "Accept: application/vnd.github.v3+json" \
          -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/repos/$OWNER/$REPO/actions/jobs/$job_id/rerun"
      done
    else
      echo "No failed jobs found for run_id $run_id with name $JOB_NAME."
    fi
  done
else
  echo "No matching workflow runs found for commit $COMMIT_SHA."
  exit 1
fi