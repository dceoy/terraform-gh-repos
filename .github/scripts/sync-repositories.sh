#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat << 'EOF'
Usage: sync-repositories.sh --tfvars-json PATH --removed-file PATH [--repositories-json PATH]
EOF
}

tfvars_json=''
repositories_json=''
removed_file=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tfvars-json)
      tfvars_json="$2"
      shift 2
      ;;
    --repositories-json)
      repositories_json="$2"
      shift 2
      ;;
    --removed-file)
      removed_file="$2"
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$tfvars_json" && -n "$removed_file" ]] || {
  usage >&2
  exit 2
}

result_file="$(mktemp)"
inventory_file="$(mktemp)"
removed_tmp="$(mktemp)"
api_file=''
cleanup() {
  rm -f "$result_file" "$inventory_file" "$removed_tmp"
  [[ -z "$api_file" ]] || rm -f "$api_file"
}
trap cleanup EXIT

if [[ -z "$repositories_json" ]]; then
  [[ -n "${GH_TOKEN:-}" ]] || {
    echo 'GH_TOKEN is required to discover public and private repositories.' >&2
    exit 1
  }
  api_file="$(mktemp)"
  gh api --paginate '/user/repos?affiliation=owner&per_page=100' \
    | jq -s 'add' > "$api_file"
  repositories_json="$api_file"
fi

jq -e 'type == "object" and (.github_owner | type == "string" and length > 0) and (.repositories | type == "object" and all(.[]; type == "object"))' "$tfvars_json" > /dev/null
jq -e 'type == "array"' "$repositories_json" > /dev/null

retired='{}'
if [[ -f "$removed_file" ]]; then
  while IFS= read -r line; do
    [[ "$line" == '# BEGIN archived repository: '* ]] || continue
    transition=${line#'# BEGIN archived repository: '}
    repo_id=${transition%%:*}
    key=${transition#*: }
    [[ "$repo_id" =~ ^[0-9]+$ ]] || continue
    retired="$(jq -c --arg id "$repo_id" --arg key "$key" '. + {($id): $key}' <<< "$retired")"
  done < "$removed_file"
fi

jq -n \
  --slurpfile inventory "$tfvars_json" \
  --slurpfile api "$repositories_json" \
  --argjson retired "$retired" '
  def fail($message): error($message);
  def repo_name($key; $entry):
    ($entry.name // $key) as $name
    | if ($name | type) != "string" or ($name | length) == 0 then
        fail("Repository \($key) has an invalid name")
      else $name end;

  $inventory[0] as $inventory
  | $inventory.github_owner as $owner
  | [
      $api[0][]
      | select(.owner.login == $owner)
      | select((.id | type) == "number" and (.name | type) == "string")
    ] as $owned
  | if ($owned | length) == 0 then
      fail("No repositories owned by \($owner) were returned")
    else . end
  | INDEX($owned[]; (.id | tostring)) as $by_id
  | INDEX($owned[]; .name) as $by_name
  | [
      $owned[]
      | select(($retired[(.id | tostring)] != null) and (.archived != true))
      | .name
    ] as $reactivated
  | if ($reactivated | length) > 0 then
      fail("Previously retired repositories became active; restore their tfvars entries and remove the corresponding removed blocks manually: \($reactivated | sort | join(", "))")
    else . end
  | (reduce ($inventory.repositories | to_entries[]) as $item (
      {entries: {}, tracked: {}, renames: [], archives: [], additions: []};
      ($item.key) as $key
      | ($item.value) as $entry
      | if ($key | test("^[A-Za-z0-9._-]+$") | not) then
          fail("Repository stable key cannot be rendered safely in Terraform state addresses: \($key)")
        else . end
      | repo_name($key; $entry) as $old_name
      | if ($entry | has("github_id")) and (($entry.github_id | type) != "number") then
          fail("Repository \($key) has an invalid github_id")
        else . end
      | ($entry.github_id // $by_name[$old_name].id) as $repo_id
      | if $repo_id == null then
          fail("Cannot initialize GitHub ID because repository is missing from API: \($old_name)")
        else . end
      | ($repo_id | tostring) as $id
      | if .tracked[$id] != null then
          fail("GitHub repository ID \($id) is used by both \(.tracked[$id]) and \($key)")
        else . end
      | if $retired[$id] != null then
          fail("Active tfvars entry \($key) is still referenced by an archived-state transition")
        else . end
      | ($by_id[$id]) as $repo
      | if $repo == null then
          fail("Refusing to modify repository missing from API response: \($old_name) (\($id))")
        else . end
      | .tracked[$id] = $key
      | if $repo.archived == true then
          .archives += [{
            id: $id,
            key: $key,
            name: $old_name,
            public: (($entry.observed_visibility // $repo.visibility // "public") == "public")
          }]
        else
          ($entry + {
            github_id: $repo.id,
            observed_visibility: ($repo.visibility // "public")
          }) as $next
          | ($next
              | if $repo.name == $key then del(.name)
                elif $old_name != $repo.name then .name = $repo.name
                else . end) as $next
          | .entries[$key] = $next
          | if $old_name != $repo.name then
              .renames += ["\($old_name) -> \($repo.name)"]
            else . end
        end
    )) as $state
  | ($retired | to_entries | map(.value)) as $retired_keys
  | reduce (
      $owned[]
      | select(.archived != true)
      | select($state.tracked[(.id | tostring)] == null)
      | select($retired[(.id | tostring)] == null)
    ) as $repo (
      $state;
      if (.entries | has($repo.name)) or ($retired_keys | index($repo.name) != null) then
        fail("Cannot add \($repo.name): its repository name is already used as a stable Terraform inventory key")
      else
        .entries[$repo.name] = {
          github_id: $repo.id,
          observed_visibility: ($repo.visibility // "public")
        }
        | .additions += [$repo.name]
      end
    )
  | .entries = (.entries | to_entries | sort_by(.key) | from_entries)
  | .additions |= sort
  | .inventory = ($inventory + {repositories: .entries})
' > "$result_file"

jq '.inventory' "$result_file" > "$inventory_file"

append_removed_block() {
  local resource_type=$1
  local resource_name=$2
  local key=$3
  cat >> "$removed_tmp" << EOF

removed {
  from = ${resource_type}.${resource_name}["${key}"]

  lifecycle {
    destroy = false
  }
}
EOF
}

archive_count="$(jq '.archives | length' "$result_file")"
if ((archive_count > 0)); then
  if [[ -f "$removed_file" ]]; then
    cat "$removed_file" > "$removed_tmp"
    printf '\n' >> "$removed_tmp"
  else
    cat > "$removed_tmp" << 'EOF'
# Generated by .github/scripts/sync-repositories.sh.
# Archived repositories are forgotten from Terraform state without modifying GitHub.
EOF
  fi

  while IFS=$'\t' read -r repo_id key public; do
    printf '\n# BEGIN archived repository: %s: %s\n' "$repo_id" "$key" >> "$removed_tmp"
    append_removed_block github_repository repo "$key"
    append_removed_block github_repository_vulnerability_alerts alerts "$key"
    append_removed_block github_repository_dependabot_security_updates dependabot "$key"
    append_removed_block github_workflow_repository_permissions actions "$key"
    if [[ "$public" == true ]]; then
      append_removed_block github_repository_ruleset branch "$key"
    fi
    printf '\n# END archived repository: %s: %s\n' "$repo_id" "$key" >> "$removed_tmp"
  done < <(jq -r '.archives[] | [.id, .key, (.public | tostring)] | @tsv' "$result_file")
fi

mv "$inventory_file" "$tfvars_json"
if ((archive_count > 0)); then
  mkdir -p "$(dirname "$removed_file")"
  mv "$removed_tmp" "$removed_file"
fi

join_or_none() {
  local filter=$1
  jq -r "$filter | if length == 0 then \"none\" else join(\", \") end" "$result_file"
}

printf 'Added: %s\n' "$(join_or_none '.additions')"
printf 'Renamed: %s\n' "$(join_or_none '.renames')"
printf 'Archived: %s\n' "$(join_or_none '[.archives[].name]')"
