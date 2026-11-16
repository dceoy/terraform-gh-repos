#!/usr/bin/env bats

setup() {
  script="${BATS_TEST_DIRNAME}/../sync-repositories.sh"
  inventory="${BATS_TEST_TMPDIR}/inventory.json"
  api="${BATS_TEST_TMPDIR}/repositories.json"
  rulesets="${BATS_TEST_TMPDIR}/rulesets.json"
  moved="${BATS_TEST_TMPDIR}/moved.tf"
}

@test "adds a newly discovered repository" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "observed_visibility": "public"
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}},
  {"id": 2, "name": "beta", "visibility": "private", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Added: beta"* ]]
  run jq -e '.repositories.beta == {"github_id": 2, "observed_visibility": "private"}' "$inventory"
  [ "$status" -eq 0 ]
}

@test "records an existing repository ruleset ID" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {}
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON
  printf '%s\n' '{"1": 99}' > "$rulesets"

  run bash "$script" \
    --tfvars-json "$inventory" \
    --repositories-json "$api" \
    --rulesets-json "$rulesets"

  [ "$status" -eq 0 ]
  run jq -e '.repositories.alpha.ruleset_id == 99' "$inventory"
  [ "$status" -eq 0 ]
}

@test "tracks a rename by GitHub ID and preserves overrides" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "observed_visibility": "public",
      "has_issues": false
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "renamed-alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --moved-file "$moved"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Renamed: alpha -> renamed-alpha"* ]]
  run jq -e '.repositories["renamed-alpha"].github_id == 1 and .repositories["renamed-alpha"].has_issues == false and (.repositories | has("alpha") | not) and (.repositories["renamed-alpha"] | has("name") | not)' "$inventory"
  [ "$status" -eq 0 ]
  run grep -F 'from = github_repository.repo["alpha"]' "$moved"
  [ "$status" -eq 0 ]
  run grep -F 'to   = github_repository.repo["renamed-alpha"]' "$moved"
  [ "$status" -eq 0 ]
  run grep -F 'from = github_repository_ruleset.branch["alpha"]' "$moved"
  [ "$status" -eq 0 ]
  run grep -F 'to   = github_repository_ruleset.branch["renamed-alpha"]' "$moved"
  [ "$status" -eq 0 ]
}

@test "retires an archived repository while preserving its stable identity" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "ruleset_id": 99,
      "observed_visibility": "public",
      "has_issues": false
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "alpha", "visibility": "public", "archived": true, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Archived: alpha"* ]]
  run jq -e '.repositories.alpha.retired == true and .repositories.alpha.github_id == 1 and .repositories.alpha.ruleset_id == 99 and .repositories.alpha.has_issues == false' "$inventory"
  [ "$status" -eq 0 ]
}

@test "reactivates a retired repository by GitHub ID and preserves ruleset identity" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "ruleset_id": 99,
      "observed_visibility": "public",
      "retired": true,
      "has_issues": false
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "renamed-alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON
  printf '%s\n' '{"1": 99}' > "$rulesets"

  run bash "$script" \
    --tfvars-json "$inventory" \
    --repositories-json "$api" \
    --rulesets-json "$rulesets" --moved-file "$moved"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Reactivated: renamed-alpha"* ]]
  run jq -e '.repositories["renamed-alpha"].retired == null and .repositories["renamed-alpha"].ruleset_id == 99 and .repositories["renamed-alpha"].has_issues == false' "$inventory"
  [ "$status" -eq 0 ]
}

@test "fails closed when an active tracked repository is missing from the API" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "observed_visibility": "public"
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 2, "name": "beta", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to modify repository missing from API response: alpha (1)"* ]]
}

@test "keeps a retired tombstone when the repository disappears from the API" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "observed_visibility": "public",
      "retired": true
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 2, "name": "beta", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"

  [ "$status" -eq 0 ]
  run jq -e '.repositories.alpha.retired == true and .repositories.alpha.github_id == 1 and .repositories.beta.github_id == 2' "$inventory"
  [ "$status" -eq 0 ]
}

@test "rejects reuse of a retired stable key by a newly discovered repository" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "observed_visibility": "public",
      "retired": true
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 2, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot add alpha: its name or stable Terraform key is reserved by an existing inventory entry"* ]]
}

@test "rejects a tracked rename that reuses a retired stable key" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "alpha": {
      "github_id": 1,
      "name": "retired-alpha",
      "observed_visibility": "public",
      "retired": true
    },
    "beta": {
      "github_id": 2,
      "observed_visibility": "public"
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "retired-alpha", "visibility": "public", "archived": true, "owner": {"login": "owner"}},
  {"id": 2, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot rename beta: target key alpha is already reserved"* ]]
}

@test "discovers repositories and repository rulesets with gh" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {}
}
JSON
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'api --paginate /installation/repositories?per_page=100')
    printf '%s\n' '{"total_count": 1, "repositories": [{"id": 1, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}]}'
    ;;
  'api --paginate /repos/owner/alpha/rulesets?per_page=100')
    printf '%s\n' '[{"id": 99, "name": "default-branch-protection", "target": "branch", "source_type": "Repository"}]'
    ;;
  *)
    exit 1
    ;;
esac
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"

  run env PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" GH_TOKEN=test-token \
    bash "$script" --tfvars-json "$inventory"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Added: alpha"* ]]
  run jq -e '.repositories.alpha.github_id == 1 and .repositories.alpha.ruleset_id == 99' "$inventory"
  [ "$status" -eq 0 ]
}

@test "migrates a legacy name override to the current repository key once" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {
    "old-name": {
      "github_id": 1,
      "name": "current-name",
      "observed_visibility": "public",
      "has_issues": false
    }
  }
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "current-name", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --moved-file "$moved"
  [ "$status" -eq 0 ]
  run jq -e '.repositories["current-name"].github_id == 1 and .repositories["current-name"].has_issues == false and (.repositories["current-name"] | has("name") | not) and (.repositories | has("old-name") | not)' "$inventory"
  [ "$status" -eq 0 ]
  run grep -c '^moved {$' "$moved"
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --moved-file "$moved"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Renamed: none"* ]]
  run grep -c '^moved {$' "$moved"
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
}

@test "rejects a rename without Terraform state migration output" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {"alpha": {"github_id": 1}}
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "beta", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--moved-file is required"* ]]
  run jq -e '.repositories | has("alpha")' "$inventory"
  [ "$status" -eq 0 ]
}

@test "rejects reusing a previous Terraform move source key" {
  cat > "$inventory" << 'JSON'
{
  "github_owner": "owner",
  "repositories": {"beta": {"github_id": 1}}
}
JSON
  cat > "$api" << 'JSON'
[
  {"id": 1, "name": "beta", "visibility": "public", "archived": false, "owner": {"login": "owner"}},
  {"id": 2, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}
]
JSON
  printf '%s\n' 'moved {' '  from = github_repository.repo["alpha"]' '  to   = github_repository.repo["beta"]' '}' > "$moved"
  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --moved-file "$moved"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot reuse a previous Terraform move source"* ]]
}
