#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat << 'EOF'
Usage: sync-repositories.sh --tfvars-json PATH [--repositories-json PATH] [--rulesets-json PATH]
EOF
}

tfvars_json=''
repositories_json=''
rulesets_json=''
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
    --rulesets-json)
      rulesets_json="$2"
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$tfvars_json" ]] || {
  usage >&2
  exit 2
}

jq -e 'type == "object" and (.github_owner | type == "string" and length > 0) and (.repositories | type == "object" and all(.[]; type == "object"))' "$tfvars_json" > /dev/null
owner="$(jq -r '.github_owner' "$tfvars_json")"

result_file="$(mktemp)"
inventory_file="$(mktemp)"
api_file=''
rulesets_file=''
cleanup() {
  rm -f "$result_file" "$inventory_file"
  [[ -z "$api_file" ]] || rm -f "$api_file"
  [[ -z "$rulesets_file" ]] || rm -f "$rulesets_file"
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

jq -e 'type == "array"' "$repositories_json" > /dev/null

if [[ -z "$rulesets_json" ]]; then
  rulesets_file="$(mktemp)"
  printf '{}\n' > "$rulesets_file"
  rulesets_json="$rulesets_file"

  if [[ -n "${GH_TOKEN:-}" && -n "$api_file" ]]; then
    while IFS=$'\t' read -r repo_id repo_name; do
      ruleset_id="$(
        gh api --paginate "/repos/${owner}/${repo_name}/rulesets?per_page=100" \
          | jq -s '
              add
              | [
                  .[]
                  | select(.source_type == "Repository")
                  | select(.name == "default-branch-protection")
                  | select(.target == "branch")
                ]
              | if length > 1 then
                  error("multiple default-branch-protection rulesets found")
                elif length == 1 then .[0].id
                else null end
            '
      )"
      jq --arg id "$repo_id" --argjson ruleset_id "$ruleset_id" \
        '. + {($id): $ruleset_id}' "$rulesets_json" > "$result_file"
      mv "$result_file" "$rulesets_json"
      result_file="$(mktemp)"
    done < <(
      jq -r --arg owner "$owner" '
        .[]
        | select(.owner.login == $owner)
        | select(.archived != true and .visibility == "public")
        | [.id, .name]
        | @tsv
      ' "$repositories_json"
    )
  fi
fi

jq -e 'type == "object" and all(to_entries[]; (.value == null) or (.value | type == "number"))' "$rulesets_json" > /dev/null

jq -n \
  --slurpfile inventory "$tfvars_json" \
  --slurpfile api "$repositories_json" \
  --slurpfile rulesets "$rulesets_json" '
  def fail($message): error($message);
  def repo_name($key; $entry):
    ($entry.name // $key) as $name
    | if ($name | type) != "string" or ($name | length) == 0 then
        fail("Repository \($key) has an invalid name")
      else $name end;
  def sync_ruleset($id; $entry):
    if ($rulesets[0] | has($id)) then
      ($rulesets[0][$id]) as $ruleset_id
      | if $ruleset_id == null then
          $entry | del(.ruleset_id)
        elif ($ruleset_id | type) == "number" then
          $entry + {ruleset_id: $ruleset_id}
        else
          fail("Repository \($id) has an invalid ruleset_id")
        end
    else $entry end;

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
  | (reduce ($inventory.repositories | to_entries[]) as $item (
      {entries: {}, tracked: {}, renames: [], archives: [], reactivations: [], additions: []};
      ($item.key) as $key
      | ($item.value) as $entry
      | if ($key | test("^[A-Za-z0-9._-]+$") | not) then
          fail("Repository stable key cannot be rendered safely in Terraform state addresses: \($key)")
        else . end
      | repo_name($key; $entry) as $old_name
      | if ($entry | has("github_id")) and (($entry.github_id | type) != "number") then
          fail("Repository \($key) has an invalid github_id")
        elif ($entry | has("ruleset_id")) and (($entry.ruleset_id | type) != "number") then
          fail("Repository \($key) has an invalid ruleset_id")
        elif ($entry.retired // false) and ($entry.github_id == null) then
          fail("Retired repository \($key) requires github_id")
        else . end
      | ($entry.github_id // $by_name[$old_name].id) as $repo_id
      | if $repo_id == null then
          if $entry.retired // false then
            .entries[$key] = $entry
          else
            fail("Cannot initialize GitHub ID because repository is missing from API: \($old_name)")
          end
        else
          ($repo_id | tostring) as $id
          | if .tracked[$id] != null then
              fail("GitHub repository ID \($id) is used by both \(.tracked[$id]) and \($key)")
            else . end
          | .tracked[$id] = $key
          | ($by_id[$id]) as $repo
          | if $repo == null then
              if $entry.retired // false then
                .entries[$key] = $entry
              else
                fail("Refusing to modify repository missing from API response: \($old_name) (\($id))")
              end
            else
              ($entry + {
                github_id: $repo.id,
                observed_visibility: ($repo.visibility // "public")
              }) as $next
              | sync_ruleset($id; $next) as $next
              | ($next
                  | if $repo.name == $key then del(.name)
                    else .name = $repo.name
                    end) as $next
              | if $repo.archived == true then
                  .entries[$key] = ($next + {retired: true})
                  | if ($entry.retired // false) then .
                    else .archives += [$old_name]
                    end
                else
                  .entries[$key] = ($next | del(.retired))
                  | if $entry.retired // false then
                      .reactivations += [$repo.name]
                    elif $old_name != $repo.name then
                      .renames += ["\($old_name) -> \($repo.name)"]
                    else . end
                end
            end
        end
    )) as $state
  | reduce (
      $owned[]
      | select(.archived != true)
      | select($state.tracked[(.id | tostring)] == null)
    ) as $repo (
      $state;
      ([.entries | to_entries[] | repo_name(.key; .value)] | index($repo.name)) as $name_collision
      | if (.entries | has($repo.name)) or $name_collision != null then
          fail("Cannot add \($repo.name): its name or stable Terraform key is reserved by an existing inventory entry")
        else
          ($repo.id | tostring) as $id
          | sync_ruleset($id; {
              github_id: $repo.id,
              observed_visibility: ($repo.visibility // "public")
            }) as $entry
          | .entries[$repo.name] = $entry
          | .additions += [$repo.name]
        end
    )
  | .entries as $entries
  | [$entries | to_entries[] | repo_name(.key; .value)] as $names
  | if ($names | unique | length) != ($names | length) then
      fail("Repository names must be unique across the inventory")
    else . end
  | [
      $entries
      | to_entries[]
      | . as $item
      | repo_name($item.key; $item.value) as $name
      | select($name != $item.key and ($entries | has($name)))
      | "\($item.key) -> \($name)"
    ] as $key_collisions
  | if ($key_collisions | length) > 0 then
      fail("Repository names must not reuse another stable Terraform key: \($key_collisions | join(", "))")
    else . end
  | .entries = (.entries | to_entries | sort_by(.key) | from_entries)
  | .additions |= sort
  | .archives |= sort
  | .reactivations |= sort
  | .inventory = ($inventory + {repositories: .entries})
' > "$result_file"

jq '.inventory' "$result_file" > "$inventory_file"
mv "$inventory_file" "$tfvars_json"

join_or_none() {
  local filter=$1
  jq -r "$filter | if length == 0 then \"none\" else join(\", \") end" "$result_file"
}

printf 'Added: %s\n' "$(join_or_none '.additions')"
printf 'Renamed: %s\n' "$(join_or_none '.renames')"
printf 'Archived: %s\n' "$(join_or_none '.archives')"
printf 'Reactivated: %s\n' "$(join_or_none '.reactivations')"
