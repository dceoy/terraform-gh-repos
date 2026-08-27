#!/usr/bin/env bats

setup() {
  script="${BATS_TEST_DIRNAME}/../sync-repositories.sh"
  inventory="${BATS_TEST_TMPDIR}/inventory.json"
  api="${BATS_TEST_TMPDIR}/repositories.json"
  removed="${BATS_TEST_TMPDIR}/removed.tf"
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

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --removed-file "$removed"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Added: beta"* ]]
  run jq -e '.repositories.beta == {"github_id": 2, "observed_visibility": "private"}' "$inventory"
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

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --removed-file "$removed"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Renamed: alpha -> renamed-alpha"* ]]
  run jq -e '.repositories.alpha.name == "renamed-alpha" and .repositories.alpha.has_issues == false' "$inventory"
  [ "$status" -eq 0 ]
}

@test "retires an archived public repository without destruction" {
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
  {"id": 1, "name": "alpha", "visibility": "public", "archived": true, "owner": {"login": "owner"}}
]
JSON

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --removed-file "$removed"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Archived: alpha"* ]]
  run jq -e '.repositories == {}' "$inventory"
  [ "$status" -eq 0 ]
  run grep -F 'from = github_repository.repo["alpha"]' "$removed"
  [ "$status" -eq 0 ]
  run grep -F 'from = github_repository_ruleset.branch["alpha"]' "$removed"
  [ "$status" -eq 0 ]
  run grep -F 'destroy = false' "$removed"
  [ "$status" -eq 0 ]
}

@test "fails closed when a tracked repository is missing from the API" {
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

  run bash "$script" --tfvars-json "$inventory" --repositories-json "$api" --removed-file "$removed"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Refusing to modify repository missing from API response: alpha (1)"* ]]
}

@test "discovers repositories with gh when no API fixture is supplied" {
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
[[ "$*" == "api --paginate /user/repos?affiliation=owner&per_page=100" ]]
printf '%s\n' '[{"id": 1, "name": "alpha", "visibility": "public", "archived": false, "owner": {"login": "owner"}}]'
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/gh"

  run env PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" GH_TOKEN=test-token \
    bash "$script" --tfvars-json "$inventory" --removed-file "$removed"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Added: alpha"* ]]
  run jq -e '.repositories.alpha.github_id == 1' "$inventory"
  [ "$status" -eq 0 ]
}
