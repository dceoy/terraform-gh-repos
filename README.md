# terraform-gh-repos

Terraform configuration for managing existing GitHub repositories with HCP Terraform.

[![CI/CD](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml)

Repository creation and destructive retirement are intentionally out of scope.

## Layout

```text
modules/
└── repos/
    ├── .terraform.lock.hcl
    ├── imports.tf
    ├── locals.tf
    ├── main.tf
    ├── outputs.tf
    ├── provider.tf
    ├── variables.tf
    └── version.tf
```

`modules/repos` is the Terraform root module. Repository inventory and per-repository overrides live in the selected JSON tfvars file.

## HCP Terraform

Create a VCS-driven workspace with:

- VCS repository: `dceoy/terraform-gh-repos`
- Working directory: `modules/repos`
- Execution mode: Remote
- Terraform version: `>= 1.16.0`

Load the environment file for plans and applies:

```text
TF_CLI_ARGS_plan=-var-file="../../envs/dceoy/repos.tfvars.json"
TF_CLI_ARGS_apply=-var-file="../../envs/dceoy/repos.tfvars.json"
```

Configure automatic run triggering for changes under `modules/repos/**` and the selected tfvars file.

### GitHub App setup

Create and install a private GitHub App for the account Terraform manages:

1. Grant repository **Administration: Read and write** and **Contents: Read and write** permissions.
2. Install the App on all repositories Terraform should manage.
3. Record the App ID and installation ID, and generate a private key.
4. Set `github_app_id`, `github_app_installation_id`, and sensitive `github_app_pem_file` as Terraform variables in the HCP Terraform workspace.

The provider uses GitHub App authentication when all three variables are set; otherwise it falls back to its normal token/CLI authentication. `github_owner` comes from the tfvars file; do not set `GITHUB_OWNER` separately.

## Repository inventory

Declare existing repositories in the environment file:

```json
{
  "github_owner": "example",
  "repositories": {
    "stable-key": {
      "github_id": 123456789,
      "name": "current-repository-name"
    },
    "another-repository": {}
  }
}
```

The map key is the stable Terraform identity. `name` defaults to the key and may change without changing the Terraform resource address.

Optional synchronization metadata includes:

- `github_id`: immutable repository identity
- `ruleset_id`: existing managed ruleset identity
- `observed_visibility`: latest visibility observed by synchronization
- `retired`: keep the repository as a tombstone while removing it from active Terraform management

Active entries must already exist and must not be archived. Terraform imports active repositories declaratively and fails when a configured repository is unexpectedly missing.

Managed resources use Terraform 1.16 `lifecycle { destroy = false }`; retiring an entry therefore removes it from state without deleting the remote GitHub resource. `github_repository` also uses `prevent_destroy = true` to block replacement.

## Inventory synchronization

`.github/workflows/sync-repositories.yml` synchronizes `envs/dceoy/repos.tfvars.json` daily and on manual dispatch. It reconciles repository additions, renames, archival/reactivation, and managed ruleset IDs through a pull request.

Configure:

- repository variable `INVENTORY_GH_APP_CLIENT_ID`
- repository secret `INVENTORY_GH_APP_PRIVATE_KEY`

The workflow GitHub App needs **Metadata: Read-only** and **Administration: Read-only** permissions and should be installed on all repositories to discover newly created repositories. No personal access token is required.

## Managed settings

Terraform manages repository feature, merge, security, Actions, and branch-ruleset settings represented by `modules/repos` and the selected inventory overrides.

Descriptions, website URLs, topics, visibility, and archive state are intentionally left unmanaged. Settings unavailable for private repositories on GitHub Free are preserved from GitHub rather than reconciled.

For public repositories, the default policy enables supported security features and applies the `default-branch-protection` ruleset. The ruleset prevents deletion and force pushes, requires pull requests, and requires review threads to be resolved, with zero mandatory approvals by default.

Review the HCP Terraform plan before the first apply to confirm adoption of existing repository settings.
