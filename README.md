# terraform-gh-repos

Terraform configuration for managing existing GitHub repositories and organization governance with HCP Terraform.

[![CI/CD](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml)

Repository creation and destructive retirement are intentionally out of scope.

## Layout

```text
envs/
└── dceoy/
    ├── .terraform.lock.hcl
    ├── env.tf
    └── repos.tfvars.json
modules/
├── org/   # Independent organization-governance root
└── repos/ # Reusable repository module
    ├── imports.tf
    ├── locals.tf
    ├── main.tf
    ├── outputs.tf
    ├── variables.tf
    └── version.tf
```

`envs/dceoy` is the HCP Terraform **root module** for repository management. Its `env.tf` declares the provider, inputs, outputs, and `module "repos"` call into reusable `modules/repos`. The inventory synchronizer creates `envs/dceoy/moved.tf` when a repository rename needs a temporary environment-specific state migration; it does not modify the reusable module. Provider authentication is configured only in the environment root; the child module exposes no unused GitHub App authentication inputs. The organization-governance root remains `modules/org` in a separate Terraform workspace.

## HCP Terraform

For the repository-management VCS-driven workspace, use:

- VCS repository: `dceoy/terraform-gh-repos`
- Working directory: `envs/dceoy`
- Execution mode: Remote
- Terraform version: `>= 1.16.0`

The `repositories` input is required and must be nonempty, so a missing or empty inventory fails validation instead of silently forgetting managed resources.

Load the existing inventory relative to the new working directory:

```text
TF_CLI_ARGS_plan=-var-file="repos.tfvars.json"
TF_CLI_ARGS_apply=-var-file="repos.tfvars.json"
```

The repository workspace's run triggers must include `envs/dceoy/**`, `modules/repos/**`, and `envs/dceoy/repos.tfvars.json`. Store the GitHub App ID, installation ID, and PEM key as HCP Terraform variables; the provider is configured by the environment root, not the shared module.

**State migration prerequisite:** Before removing historical root-to-`module.repos.*` move declarations, apply the original migration in the existing HCP Terraform workspace, preserving the same remote State. If a workspace still has unmigrated root addresses, restore the necessary `moved` blocks before planning or applying this cleanup. Validate that the workspace uses `envs/dceoy`, loads `repos.tfvars.json`, and the Terraform plan contains no unexpected create, destroy, or replace operations.

**Important:** Merely changing the HCP working directory without deploying the new root configuration is unsafe. Coordinate the workspace setting with the merge and first plan/apply, and do not allow a run using an incompatible working directory. Validate the environment variables and relative tfvars path on the first run.

The organization-governance workspace remains unchanged:

- VCS repository: `dceoy/terraform-gh-repos`
- Working directory: `modules/org`
- Execution mode: Remote
- Terraform version: `>= 1.16.0`

For a VCS-driven organization workspace, prefer HCP Terraform workspace or variable-set values for `github_owner`, sensitive `github_owner_token`, `organization_settings`, `actions`, and the optional `default_branch_ruleset`. Do not set the file-based `TF_CLI_ARGS_*` variables below when those Terraform variables are configured in HCP.

Alternatively, load the organization environment file for plans and applies:

```text
TF_CLI_ARGS_plan=-var-file="../../envs/<organization>/org.tfvars.json"
TF_CLI_ARGS_apply=-var-file="../../envs/<organization>/org.tfvars.json"
```

Because `.gitignore` excludes `*.tfvars.json`, an HCP VCS workspace can use a file-based option only when the file is deliberately reviewed and force-added, for example with `git add -f envs/<organization>/org.tfvars.json`. Keep App credentials and the organization-owner user token in sensitive HCP variables and do not force-add private keys or tokens. Keep the organization and repositories workspaces and states separate. Configure the organization workspace to trigger on `modules/org/**` and, when tracked, its selected environment file.

### Authentication and GitHub App permissions

Create and install a private GitHub App for the organization Terraform manages. The `modules/org` workspace uses App installation authentication for Actions policy and rulesets, while organization settings use a separate organization-owner user token so private organization fields can be read reliably.

1. Grant the App organization **Administration: Read and write** for Actions policy and rulesets.
2. Grant the App repository **Metadata: Read-only** when `actions.enabled_repositories` is `selected`, so configured repository IDs can be resolved.
3. Install the App on the organization and on any repositories required by a selected Actions policy.
4. Record the App ID and installation ID, generate a private key, and set `github_app_id`, `github_app_installation_id`, and sensitive `github_app_pem_file` as Terraform variables in the organization HCP Terraform workspace. Ambient `GITHUB_APP_*` variables cannot replace these inputs.
5. Set sensitive `github_owner_token` to a user token belonging to an owner of the managed organization. A fine-grained personal access token or GitHub App user access token needs organization **Administration: Read and write** for the update path; a personal access token (classic) needs `admin:org`. This token is used only by the aliased provider for `github_organization_settings` and its private organization read path.

`modules/org` does not require organization **Members** permission or repository **Administration** permission because it does not manage members, teams, memberships, or team-to-repository access. If the same App is also used by the repository-management workspace (`envs/dceoy`), grant its separately required repository permissions.

The default provider uses GitHub App installation authentication for Actions policy, repository metadata lookup, and organization rulesets. The `github.owner` provider alias uses `github_owner_token` only for organization settings and the billing-email read required by the provider schema. `github_owner` comes from the selected tfvars file or HCP Terraform variables. Both providers receive `owner` and the deprecated `organization` setting from that same value because provider 6.13.0 checks the legacy setting first; unset both `GITHUB_OWNER` and `GITHUB_ORGANIZATION` in local and HCP execution environments so ambient selectors cannot redirect the root. There is no GitHub CLI credential fallback when the required App credentials and owner token are configured.

## Organization governance

`modules/org` manages organization governance rather than organization profile or billing metadata. Like `modules/repos`, managed organization settings are configurable through Terraform variables and use policy-oriented defaults when omitted. The defaults set `default_repository_permission = "none"`, enable organization and repository Projects plus web commit signoff, disable member-created repositories and Pages sites, disable private-repository forking, and enable Dependency Graph, Dependabot alerts, and Dependabot security updates for new repositories. Repository-specific workflow permissions remain in `modules/repos`.

Billing email and profile metadata such as company, public email, name, description, blog, location, and Twitter username are preserved outside Terraform management. Advanced Security and secret-scanning defaults remain unmanaged because availability and billing depend on the organization plan. Internal-repository creation policy is also left unmanaged because it is Enterprise-specific.

As a safety boundary, `modules/org` does not manage organization members, teams, team memberships, or team-to-repository permissions. Existing access-control objects remain outside Terraform management.

The module intentionally excludes Enterprise-only or separately billed capabilities, including internal-repository organization settings, SAML or IdP team synchronization, enterprise account policies, Enterprise Managed Users, custom organization roles, and organization-wide Advanced Security defaults.

### Organization environment file

Create `envs/<organization>/org.tfvars.json` for the organization workspace. The file is ignored by default because it contains organization-specific data. Provide only organization setting overrides that differ from the module defaults, and provide `ruleset_id` only when adopting an existing organization ruleset.

The JSON example intentionally omits the required `github_owner_token`, `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` inputs. Supply those values separately through sensitive HCP Terraform variables or securely exported `TF_VAR_*` inputs; never store user tokens or the App private key in the environment file.

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
    "enforcement": "disabled"
  }
}
```

The first plan imports organization settings and Actions policy automatically. The current billing email is read through the organization-owner provider only to satisfy the provider schema and is ignored for changes, so it remains outside Terraform management. Review the effective organization setting values, Actions policy, and ruleset before the first apply. When `ruleset_id` is set, the existing ruleset is imported into `github_organization_ruleset.branch` and reconciled to the configured policy. Organization ruleset name, repository/ref selectors, deletion and force-push protection, linear-history policy, merge methods, review requirements, exclusions, and approval count can all be overridden through `default_branch_ruleset`; omitted fields retain the module defaults. Changing `ruleset_id` after import does not rebind existing state; explicitly remove and import the intended object at the same resource address before changing an adoption ID.

The locked GitHub provider 6.13.0 does not reliably serialize `sha_pinning_required = false` or an empty selected-action pattern set. The module therefore requires SHA pinning and a non-empty `patterns_allowed` set when `allowed_actions` is `selected`; revisit these constraints after upgrading to a provider release that supports both updates.

### Organization and repository ruleset ownership

`modules/repos` owns repository-level `default-branch-protection` rulesets by default. Repository ruleset policy is configured through the `default_branch_ruleset` variable. When the organization workspace owns the shared policy, set the repository workspace variable `manage_default_branch_repository_rulesets` to `false`. Do not manage the same protection policy at both scopes.

Transfer ownership in stages:

1. For a new organization ruleset, omit `ruleset_id`, set `enforcement` to `disabled`, and apply `modules/org`. For an existing ruleset, provide `ruleset_id`, set the policy fields to the intended values, and verify that it is the dedicated default-branch ruleset before applying.
2. Set the organization ruleset to `active` and apply `modules/org` while the old repository rulesets remain active. Verify that the organization ruleset targets the intended repositories and is effective.
3. Set `manage_default_branch_repository_rulesets` to `false` and apply the repository-management workspace; the child module's `destroy = false` lifecycle forgets repository ruleset state without deleting the remote rulesets.
4. Deliberately remove the old repository rulesets only after active organization protection has been verified.

For rollback, restore repository-level ownership and protection before disabling or removing the organization ruleset. By default, organization rulesets target `~ALL` repositories and `~DEFAULT_BRANCH`, prevent deletion and force pushes, require pull requests and resolved review threads, and require zero approvals; each of those policy values is configurable.

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

The map key tracks the current GitHub repository name. The synchronizer matches repositories by immutable `github_id`; when a repository is renamed, it updates the map key and adds environment-root Terraform `moved` blocks under `envs/dceoy/moved.tf` to preserve the child module's state addresses. The optional `name` override remains supported for legacy or manual inventories but is removed by synchronization.

Optional synchronization metadata includes:

- `github_id`: immutable repository identity
- `ruleset_id`: existing managed ruleset identity
- `observed_visibility`: latest visibility observed by synchronization
- `retired`: keep the repository as a tombstone while removing it from active Terraform management

Repository feature, merge, Actions, Dependabot, vulnerability-alert, and public-repository `security_and_analysis` settings are optional per-repository overrides. Omitted values use the defaults defined in `modules/repos/variables.tf`.

Active entries must already exist and must not be archived. Terraform imports active repositories declaratively and fails when a configured repository is unexpectedly missing.

Managed resources use Terraform 1.16 `lifecycle { destroy = false }`; retiring an entry therefore removes it from state without deleting the remote GitHub resource. `github_repository` also uses `prevent_destroy = true` to block replacement.

## Inventory synchronization

`.github/workflows/sync-repositories.yml` synchronizes `envs/dceoy/repos.tfvars.json` daily and on manual dispatch. It reconciles repository additions, renames, archival/reactivation, and managed ruleset IDs through a pull request. Renames generate `module.repos.*` state migration definitions in `envs/dceoy/moved.tf`, never inside the reusable child module. Generate the file only for pending renames, and remove its migration blocks only after the relevant workspace state has advanced. Review every HCP Terraform plan for unexpected resource destruction or replacement. Historical move sources are reserved while their migration blocks remain.

Configure:

- repository variable `INVENTORY_GH_APP_CLIENT_ID`
- repository secret `INVENTORY_GH_APP_PRIVATE_KEY`

The workflow GitHub App needs **Metadata: Read-only** and **Administration: Read-only** permissions and should be installed on all repositories to discover newly created repositories. No personal access token is required.

## Managed settings

Terraform manages repository feature, merge, security, Actions, and branch-ruleset settings represented by `modules/repos` and the selected inventory overrides. Managed policy values are variable-driven; defaults reproduce the repository policy previously encoded directly in `main.tf`.

Descriptions, website URLs, topics, visibility, and archive state are intentionally left unmanaged. Settings unavailable for private repositories on GitHub Free are preserved from GitHub rather than reconciled.

For public repositories, the default policy enables supported security features and applies the `default-branch-protection` ruleset. The default ruleset prevents deletion and force pushes, requires pull requests and resolved review threads, permits merge/squash/rebase, and requires zero approvals. These security and ruleset defaults can be overridden through `repositories.*.security_and_analysis` and `default_branch_ruleset` respectively.

Review the HCP Terraform plan before the first apply to confirm adoption of existing repository settings.
