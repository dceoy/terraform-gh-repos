# terraform-gh-repos

Terraform configuration for managing existing GitHub repositories and organization governance with HCP Terraform.

[![CI/CD](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml)

Repository creation and destructive retirement are intentionally out of scope.

## Layout

```text
modules/
├── org/
│   ├── .terraform.lock.hcl
│   ├── imports.tf
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── version.tf
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

`modules/repos` and `modules/org` are independent Terraform root modules. Repository inventory and per-repository overrides live in `repos.tfvars.json`; organization settings and Actions/ruleset policy live in `org.tfvars.json`. The modules do not share Terraform state.

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

Create a second VCS-driven workspace for organization governance:

- VCS repository: `dceoy/terraform-gh-repos`
- Working directory: `modules/org`
- Execution mode: Remote
- Terraform version: `>= 1.16.0`

For a VCS-driven workspace, prefer HCP Terraform workspace or variable-set values for `github_owner`, `organization_settings`, `actions`, and the optional `default_branch_ruleset`. Do not set the file-based `TF_CLI_ARGS_*` variables below when those Terraform variables are configured in HCP.

Alternatively, load the organization environment file for plans and applies:

```text
TF_CLI_ARGS_plan=-var-file="../../envs/<organization>/org.tfvars.json"
TF_CLI_ARGS_apply=-var-file="../../envs/<organization>/org.tfvars.json"
```

Because `.gitignore` excludes `*.tfvars.json`, an HCP VCS workspace can use the file-based option only when the file is deliberately reviewed and force-added, for example with `git add -f envs/<organization>/org.tfvars.json`. Keep App credentials in sensitive HCP variables and do not force-add private keys. Keep the `modules/org` and `modules/repos` workspaces and state separate. Configure the organization workspace to trigger on `modules/org/**` and, when tracked, its selected environment file.

### GitHub App permissions

Create and install a private GitHub App for the organization Terraform manages. The `modules/org` workspace requires explicit App authentication; grant only the permissions needed by the configured resources:

1. Grant organization **Administration: Read and write** for organization settings, Actions policy, and rulesets.
2. Grant repository **Metadata: Read-only** when `actions.enabled_repositories` is `selected`, so configured repository IDs can be resolved.
3. Install the App on the organization and on any repositories required by a selected Actions policy.
4. Record the App ID and installation ID, generate a private key, and set `github_app_id`, `github_app_installation_id`, and sensitive `github_app_pem_file` as Terraform variables in the `modules/org` HCP Terraform workspace. The organization root does not use token or CLI fallback, and ambient `GITHUB_APP_*` variables cannot replace these inputs.

`modules/org` does not require organization **Members** permission or repository **Administration** permission because it does not manage members, teams, memberships, or team-to-repository access. If the same App is also used by `modules/repos`, grant the separate repository permissions required by that root.

The selected organization settings, Actions, and ruleset operations use GitHub App installation authentication; a user token is not required for this scope. `github_owner` comes from the selected tfvars file or HCP Terraform variables. The provider receives both `owner` and its deprecated `organization` setting from that same value because provider 6.13.0 checks the legacy setting first; unset both `GITHUB_OWNER` and `GITHUB_ORGANIZATION` in local and HCP execution environments so ambient selectors cannot redirect the root.

## Organization governance

`modules/org` manages organization governance rather than organization profile or billing metadata. Like `modules/repos`, managed organization settings are configurable through Terraform variables and use policy-oriented defaults when omitted. The defaults set `default_repository_permission = "none"`, enable organization and repository Projects plus web commit signoff, disable member-created repositories and Pages sites, disable private-repository forking, and enable Dependency Graph, Dependabot alerts, and Dependabot security updates for new repositories. Repository-specific workflow permissions remain in `modules/repos`.

Billing email and profile metadata such as company, public email, name, description, blog, location, and Twitter username are preserved outside Terraform management. Advanced Security and secret-scanning defaults remain unmanaged because availability and billing depend on the organization plan. Internal-repository creation policy is also left unmanaged because it is Enterprise-specific.

As a safety boundary, `modules/org` does not manage organization members, teams, team memberships, or team-to-repository permissions. Existing access-control objects remain outside Terraform management.

The module intentionally excludes Enterprise-only or separately billed capabilities, including internal-repository organization settings, SAML or IdP team synchronization, enterprise account policies, Enterprise Managed Users, custom organization roles, and organization-wide Advanced Security defaults.

### Organization environment file

Create `envs/<organization>/org.tfvars.json` for the organization workspace. The file is ignored by default because it contains organization-specific data. Provide only organization setting overrides that differ from the module defaults, and provide `ruleset_id` only when adopting an existing organization ruleset.

The JSON example intentionally omits the required `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` inputs. Supply those values separately through sensitive HCP Terraform variables or securely exported `TF_VAR_*` inputs; never store the private key in the environment file.

```json
{
  "github_owner": "example-org",
  "organization_settings": {
    "has_organization_projects": true,
    "has_repository_projects": true,
    "web_commit_signoff_required": true
  },
  "actions": {
    "enabled_repositories": "all",
    "selected_repositories": [],
    "allowed_actions": "selected",
    "allowed_actions_config": {
      "github_owned_allowed": true,
      "verified_allowed": true,
      "patterns_allowed": ["actions/cache@*", "actions/checkout@*"]
    },
    "sha_pinning_required": true,
    "default_workflow_permissions": "read",
    "can_approve_pull_request_reviews": false
  },
  "default_branch_ruleset": {
    "enforcement": "disabled",
    "repository_exclusions": [],
    "required_approving_review_count": 0
  }
}
```

The first plan imports organization settings and Actions policy automatically. The current billing email is read from GitHub only to satisfy the provider schema and is ignored for changes, so it remains outside Terraform management. Review the effective organization setting values, Actions policy, and ruleset before the first apply. When `ruleset_id` is set, the existing ruleset is imported into `github_organization_ruleset.branch` and reconciled to the configured enforcement, conditions, rules, and exclusions. Configure those fields to the intended policy before the first apply. Changing `ruleset_id` after import does not rebind existing state; explicitly remove and import the intended object at the same resource address before changing an adoption ID.

The locked GitHub provider 6.13.0 does not reliably serialize `sha_pinning_required = false` or an empty selected-action pattern set. The module therefore requires SHA pinning and a non-empty `patterns_allowed` set when `allowed_actions` is `selected`; revisit these constraints after upgrading to a provider release that supports both updates.

### Organization and repository ruleset ownership

`modules/repos` owns repository-level `default-branch-protection` rulesets by default. When the organization workspace owns the shared policy, set the `modules/repos` workspace variable `manage_default_branch_repository_rulesets` to `false`. Do not manage the same protection policy at both scopes.

Transfer ownership in stages:

1. For a new organization ruleset, omit `ruleset_id`, set `enforcement` to `disabled`, and apply `modules/org`. For an existing ruleset, provide `ruleset_id`, set the documented policy fields to the intended values, and verify that it is the dedicated default-branch ruleset before applying.
2. Set the organization ruleset to `active` and apply `modules/org` while the old repository rulesets remain active. Verify that the organization ruleset targets the intended repositories and is effective.
3. Set `manage_default_branch_repository_rulesets` to `false` and apply `modules/repos`; its `destroy = false` lifecycle forgets repository ruleset state without deleting the remote rulesets.
4. Deliberately remove the old repository rulesets only after active organization protection has been verified.

For rollback, restore repository-level ownership and protection before disabling or removing the organization ruleset. Organization rulesets target `~ALL` repositories except configured name exclusions and otherwise match the existing default-branch policy with zero required approvals by default.

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
