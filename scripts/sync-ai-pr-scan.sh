#!/usr/bin/env bash
set -euo pipefail

# Reconcile GitHub AI pull-request scanning for managed public repositories.
# Requires GH_TOKEN with repository Administration: write permission.
# Usage: ./scripts/sync-ai-pr-scan.sh envs/dceoy/repos.tfvars.json [enabled|disabled]
inventory="${1:?Specify the repository inventory JSON file}"
status="${2:-enabled}"
if [[ "${status}" != enabled && "${status}" != disabled ]]; then
  echo 'Status must be enabled or disabled' >&2
  exit 2
fi
for tool in gh jq; do
  command -v "${tool}" >/dev/null || { echo "Missing ${tool}" >&2; exit 2; }
done
owner="$(jq -er '.github_owner' "${inventory}")"
jq -r '.repositories | to_entries[] | select(.value.retired != true and .value.observed_visibility == "public") | (.value.name // .key)' "${inventory}" |
while IFS= read -r name; do
  echo "Configuring AI PR scan: ${owner}/${name} (${status})"
  gh api --method PATCH "repos/${owner}/${name}/code-scanning/ai-scan" -f "pr_scan=${status}"
done
