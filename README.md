# terraform-gh-repos

Terraform configuration for managing existing GitHub repositories and organization governance with HCP Terraform.

[![CI/CD](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml/badge.svg)](https://github.com/dceoy/terraform-gh-repos/actions/workflows/ci.yml)

Repository creation and destructive retirement are intentionally out of scope.

## Layout

```text
modules/
├── org/
│   ├── .terraform.lock.hcl
│   ├── access.tf
│   ├── actions.tf
│   ├── imports.tf
│   ├── locals.tf
│   ├── members.tf
│   ├── organization.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── rulesets.tf
│   ├── teams.tf
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

`modules/repos` and `modules/org` are independent Terraform root modules. Repository inventory and per-repository overrides live in `repos.tfvars.json`; organization settings and access policy live in `org.tfvars.json`. The modules do not share Terraform state.

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

Load the organization environment file for plans and applies:

```text
TF_CLI_ARGS_plan=-var-file="../../envs/<organization>/org.tfvars.json"
TF_CLI_ARGS_apply=-var-file="../../envs/<organization>/org.tfvars.json"
```

Keep the `modules/org` and `modules/repos` workspaces and state separate. Configure the organization workspace to trigger on `modules/org/**` and its selected environment file.

### GitHub App permissions

Create and install a private GitHub App for the organization Terraform manages. For `modules/org`, grant only the permissions needed by the configured resources:

1. Grant organization **Administration: Read and write** and **Members: Read and write** permissions.
2. Grant repository **Administration: Read and write** and **Metadata: Read-only** permissions.
3. If the same App is used by `modules/repos`, also grant repository **Contents: Read and write**.
4. Install the App on the organization and all repositories Terraform should manage.
5. Record the App ID and installation ID, and generate a private key.
6. Set `github_app_id`, `github_app_installation_id`, and sensitive `github_app_pem_file` as Terraform variables in each HCP Terraform workspace.

The selected organization settings, membership, team, Actions, and ruleset operations support GitHub App installation authentication; a user token is not required for this scope. The provider uses App authentication when all three variables are set; otherwise it falls back to its normal token/CLI authentication. `github_owner` comes from the selected tfvars file; do not set `GITHUB_OWNER` separately.

## Organization governance

`modules/org` manages organization settings, configured members, teams, team memberships, team-to-repository permissions, organization Actions policy, and an optional organization default-branch ruleset. Membership and access maps are non-authoritative: users, teams, and grants not listed in `org.tfvars.json` are not managed. Repository-specific workflow permissions remain in `modules/repos`.

The module intentionally excludes Enterprise-only or separately billed capabilities, including internal-repository organization settings, SAML or IdP team synchronization, enterprise account policies, Enterprise Managed Users, custom organization roles, and organization-wide Advanced Security defaults.

### Organization environment file

Create `envs/<organization>/org.tfvars.json` for the organization workspace. The file is ignored by default because it contains organization-specific data. Replace example IDs with IDs from the target organization; omit an ID when creating a new team or ruleset instead of adopting an existing one.

```json
{
  "github_owner": "example-org",
  "organization_settings": {
    "billing_email": "admin@example.org",
    "default_repository_permission": "none",
    "members_can_create_repositories": false,
    "web_commit_signoff_required": true
  },
  "members": {
    "alice": {
      "role": "admin",
      "downgrade_on_destroy": true
    },
    "bob": {
      "role": "member"
    }
  },
  "teams": {
    "engineering": {
      "team_id": 123456,
      "description": "Engineering",
      "members": {
        "bob": {
          "role": "member"
        }
      },
      "repositories": {
        "example-repository": "push"
      }
    }
  },
  "actions": {
    "enabled_repositories": "all",
    "allowed_actions": "selected",
    "allowed_actions_config": {
      "github_owned_allowed": true,
      "verified_allowed": true,
      "patterns_allowed": ["actions/cache@*", "actions/checkout@*"]
    },
    "default_workflow_permissions": "read",
    "can_approve_pull_request_reviews": false
  },
  "default_branch_ruleset": {
    "enforcement": "disabled",
    "required_approving_review_count": 0
  }
}
```

The first plan imports organization settings and Actions policy automatically. Provide `team_id` and `ruleset_id` for existing resources so they are adopted rather than recreated. Memberships and team access are non-authoritative provider operations that adopt or create only the configured associations. Review the first plan carefully: removing a membership, team membership, or team-repository entry changes remote access, even though removing organization settings, teams, Actions policy, or the ruleset from configuration does not destroy those remote resources.

### Organization and repository ruleset ownership

`modules/repos` owns repository-level `default-branch-protection` rulesets by default. When the organization workspace owns the shared policy, set the `modules/repos` workspace variable `manage_default_branch_repository_rulesets` to `false`. Do not manage the same protection policy at both scopes.

Transfer ownership in stages:

1. Configure and import the organization ruleset with `enforcement` set to `disabled`.
2. Set `manage_default_branch_repository_rulesets` to `false` and apply `modules/repos`; its `destroy = false` lifecycle forgets repository ruleset state without deleting the remote rulesets.
3. Deliberately remove the old repository rulesets after verifying the organization ruleset targets the intended repositories.
4. Set the organization ruleset to `active` and apply `modules/org`.

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
