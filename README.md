# terraform-gh-repos

Terraform configuration for managing GitHub repositories with HCP Terraform. The included `dceoy` environment manages repositories in the `dceoy` GitHub personal account.

[![CI/CD](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml)

## Architecture

```text
GitHub repository
    |
    | VCS integration
    v
HCP Terraform
    |
    | working directory: modules/repos
    | remote plan / apply / state
    v
GitHub API
```

Terraform manages existing, active repositories declared in `envs/dceoy.tfvars.json`. Repository creation and destructive retirement are intentionally out of scope.

## Layout

```text
envs/
└── dceoy.tfvars.json

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

`modules/repos` contains no persistent `dceoy`-specific repository list. Repository identity and synchronization metadata live in the selected JSON tfvars file.

## HCP Terraform

### GitHub App setup

Create a private GitHub App owned by the target GitHub account:

1. Open **Settings > Developer settings > GitHub Apps > New GitHub App**.
2. Set a unique app name and use this repository URL as the Homepage URL. OAuth callback and setup URLs are not required.
3. Disable **Webhook > Active**; Terraform does not consume GitHub App webhooks.
4. Grant these repository permissions:
   - **Administration: Read and write**
   - **Contents: Read and write**
5. Select **Only on this account** for where the app can be installed, then create the app.
6. Record the **App ID** and generate a private key under **Private keys**. Keep the downloaded PEM private.
7. Open **Install App** and install it on the target account. Select **All repositories** if Terraform should manage repositories without updating the installation each time; otherwise select only the repositories Terraform manages.
8. After installation, open the installation settings and record the numeric installation ID from the URL (`/settings/installations/<installation-id>`).

The App ID and installation ID are identifiers, not secrets. The generated PEM private key is a secret and must not be committed to this repository.

### Workspace setup

Create a VCS-driven workspace with:

- VCS repository: `dceoy/terraform-gh-repos`
- Terraform working directory: `modules/repos`
- Execution mode: Remote
- Terraform version: `>= 1.16.0`

Terraform 1.16 is required because managed resources use `lifecycle { destroy = false }` so instances removed from `for_each` are forgotten from state instead of destroyed remotely.

Configure these environment variables so Terraform loads the environment-specific variable file for both planning and applying:

```text
TF_CLI_ARGS_plan=-var-file="../../envs/dceoy.tfvars.json"
TF_CLI_ARGS_apply=-var-file="../../envs/dceoy.tfvars.json"
```

Configure automatic run triggering for changes under `modules/repos/**` and `envs/dceoy.tfvars.json`, because the variable file is outside the Terraform working directory.

Store GitHub App credentials as Terraform variables on the workspace: `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` (the PEM file contents, including newlines). Mark only `github_app_pem_file` as sensitive; the app and installation IDs are identifiers, not secrets. The provider uses GitHub App authentication only when all three are set; otherwise it uses `GITHUB_TOKEN` or the provider's normal token/CLI authentication. These must be Terraform variables, not environment variables — the module reads them itself and passes them into the `github` provider's `app_auth` block.

For GitHub App authentication, grant the app repository `Administration: Read and write` and `Contents: Read and write` permissions. Administration covers the repository settings managed here, rulesets, vulnerability alerts, security settings, and workflow-permission reconciliation. Contents read/write is required for GitHub to expose the merge-related repository settings that Terraform manages.

Do not set `GITHUB_OWNER`; the owner is configured by the required Terraform variable `github_owner` in the selected environment JSON tfvars file.

## Repository inventory

Add the target account and existing repositories explicitly to the environment JSON tfvars file:

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

The map key is the stable Terraform identity for each repository. `name` is optional and defaults to that key. Keeping the key unchanged while updating `name` allows an externally renamed GitHub repository to remain at the same Terraform resource address without a `moved` block.

`github_id` is optional synchronization metadata used to distinguish a rename from repository replacement. `ruleset_id` is optional synchronization metadata for the managed `default-branch-protection` ruleset; when present, Terraform uses a config-driven import to recover an existing ruleset after `destroy = false` has forgotten it from state. `observed_visibility` records the latest visibility observed by the synchronizer but does not control Terraform visibility or retirement behavior. Environments that do not use synchronization can continue to use simple `{}` entries.

Active inventory entries must already exist in the configured `github_owner` account and must not be archived. Terraform reads and imports each active repository automatically; a missing active repository makes synchronization fail closed rather than silently removing it.

Repository names are unique across the inventory and cannot reuse another entry's stable Terraform key. This reservation applies to both active and retired entries so an external rename cannot silently alias a tombstoned state address.

### Retirement safety

A repository with `retired: true` remains in the JSON inventory as a tombstone but is excluded from all Terraform `for_each` collections and imports. The tombstone preserves the immutable GitHub ID, stable Terraform key, current name, ruleset ID when known, and any per-repository overrides.

All managed GitHub resources use Terraform 1.16 `lifecycle { destroy = false }`. When an active repository becomes retired, Terraform therefore forgets the corresponding resource instances from state without issuing destructive GitHub API calls. The `github_repository` resource also retains `prevent_destroy = true`, so replacement operations remain blocked while ordinary retirement is handled as a state-only forget.

The same no-destroy policy applies when a public-only managed binding such as a ruleset leaves configuration. Terraform stops managing that binding without deleting the remote object. When the repository becomes public and active again, the synchronizer records the existing ruleset ID and the import block reattaches Terraform state instead of creating a duplicate ruleset.

Retired tombstones reserve their stable key and repository identity. If the same GitHub repository is later unarchived, synchronization removes `retired` and restores management at the original Terraform address. If a different repository attempts to reuse a retired key or name, synchronization fails for manual reconciliation.

## Inventory synchronization

`.github/workflows/sync-repositories.yml` synchronizes the `dceoy` inventory daily at 00:17 UTC and on manual dispatch. It discovers repositories owned by the authenticated user and reconciles additions, renames, archival, reactivation, and managed ruleset identity through a pull request.

Configure the repository secret `GH_INVENTORY_TOKEN` with a fine-grained personal access token owned by `dceoy`. Select **All repositories** and grant only **Metadata: Read-only** repository permission so future private repositories and repository rulesets are discoverable without giving the inventory token write access. The workflow uses the normal Actions `GITHUB_TOKEN` separately for pull-request creation.

The synchronizer uses immutable GitHub repository IDs as identity anchors while keeping the JSON map key stable. It preserves arbitrary per-repository overrides across renames and retirement. For active public repositories it also records the repository-owned `default-branch-protection` ruleset ID when one exists; an absent ruleset ID allows Terraform to create the ruleset normally. An active tracked GitHub ID missing from the API response causes a failure instead of deletion, protecting against incorrectly scoped tokens, transfers, deletions, and transient inventory gaps. A retired tombstone may remain when its remote repository disappears so its Terraform identity cannot be accidentally reused.

The workflow uses `peter-evans/create-pull-request` to create or update `github-actions/repository-inventory` and to manage the synchronization branch lifecycle. CI is not explicitly dispatched by the synchronization workflow.

## Managed settings

Repository descriptions, website URLs, topics, visibility, and archive state are intentionally left unmanaged and retain their current GitHub values. Terraform manages repository feature and merge settings from inventory defaults/overrides where those settings are available on GitHub Free. Projects, discussions, and wikis default to disabled.

For private repositories on GitHub Free, settings unavailable on that plan are preserved from their observed GitHub values rather than reconciled. In particular, wiki and auto-merge settings are retained for private repositories; public repositories continue to use the inventory defaults/overrides.

The default security policy enables Dependabot vulnerability alerts and security updates, gives the default Actions `GITHUB_TOKEN` read-only permissions, and allows GitHub Actions to approve pull requests. Workflows that require write access must request it explicitly at workflow or job scope.

For public repositories, where GitHub Free supports the features, Terraform also enables Code Security, secret scanning, secret-scanning push protection, AI-based secret detection, non-provider secret patterns, and one identical default-branch ruleset per repository. The common ruleset prevents branch deletion and force pushes, requires changes through pull requests with zero mandatory approvals, and requires review threads to be resolved. Private repositories are excluded from active ruleset and public-only security configuration.

Existing repository-owned `default-branch-protection` rulesets are discovered by the inventory synchronizer and recorded as `ruleset_id`. Terraform's declarative import block then attaches the matching ruleset to `github_repository_ruleset.branch["<stable-key>"]`; no manual one-off import is required when synchronization metadata is present.

Review the HCP Terraform plan before applying when first importing an existing repository because Terraform will reconcile its managed GitHub settings while leaving the repository description, website URL, topics, visibility, and archive state unchanged.
