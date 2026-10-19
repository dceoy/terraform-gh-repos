#!/usr/bin/env bash
set -euo pipefail

# Reconcile GitHub AI pull-request scanning for non-retired public repositories.
# Usage: sync-ai-pr-scan.sh INVENTORY [enabled|disabled] [--apply]
inventory="${1:?Specify the repository inventory JSON file}"
status="${2:-enabled}"
mode="${3:---dry-run}"
if [[ "${status}" != enabled && "${status}" != disabled ]]; then
  echo 'Status must be enabled or disabled' >&2
  exit 2
fi
if [[ "${mode}" != --apply && "${mode}" != --dry-run ]]; then
  echo 'Third argument must be --apply or --dry-run' >&2
  exit 2
fi
for tool in gh jq; do
  command -v "${tool}" >/dev/null || { echo "Missing ${tool}" >&2; exit 2; }
done
owner="$(jq -er '.github_owner' "${inventory}")"
jq -er '.repositories | to_entries[] | map(select(.value.retired != true and .value.observed_visibility == "public") | (.value.name // .key)) | .[]' "${inventory}" |
while IFS= read -r name; do
  echo "AI PR scan: ${owner}/${name} -> ${status} (${mode})"
  if [[ "${mode}" == --apply ]]; then
    gh api --method PATCH "repos/${owner}/${name}/code-scanning/ai-scan" -f "pr_scan=${status}" >/dev/null
  fi
done
