#!/bin/bash

set -ex

for f in $(curl  -s -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${REPOSITORY}/actions/runs" | jq -r '.workflow_runs[] | select(.conclusion == "skipped") | .rerun_url')
do
  curl -s --header "Authorization: token ${ACCESS_TOKEN}" -X POST "$f"
done

exit 0