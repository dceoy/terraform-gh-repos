# terraform-gh-repos

Terraform configuration for managing GitHub repositories with HCP Terraform. The included `dceoy` environment manages repositories in the `dceoy` GitHub personal account.

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

Terraform manages only existing, active repositories declared in `envs/dceoy.tfvars`. The included `dceoy` inventory declares all currently unarchived repositories in the account, so applying it reconciles the managed settings across that inventory. Repository creation and archived repositories are intentionally out of scope.

## Layout

```text
envs/
└── dceoy.tfvars

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

Configure these environment variables so Terraform loads the environment-specific variable file for both planning and applying:

```text
TF_CLI_ARGS_plan=-var-file="../../envs/dceoy.tfvars"
TF_CLI_ARGS_apply=-var-file="../../envs/dceoy.tfvars"
```

Configure automatic run triggering for changes under `modules/repos/**` and `envs/dceoy.tfvars`, because the variable file is outside the Terraform working directory.

Store GitHub App credentials as Terraform variables on the workspace: `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` (the PEM file contents, including newlines). Mark only `github_app_pem_file` as sensitive; the app and installation IDs are identifiers, not secrets. The provider uses GitHub App authentication only when all three are set; otherwise it uses `GITHUB_TOKEN` or the provider's normal token/CLI authentication. These must be Terraform variables, not environment variables — the module reads them itself and passes them into the `github` provider's `app_auth` block.

For GitHub App authentication, grant the app repository `Administration: Read and write` and `Contents: Read and write` permissions. Administration covers the repository settings managed here, rulesets, vulnerability alerts, security settings, and workflow-permission reconciliation. Contents read/write is required for GitHub to expose the merge-related repository settings that Terraform manages.

Do not set `GITHUB_OWNER`; the owner is configured by the required Terraform variable `github_owner` in the selected environment tfvars.

## Repository inventory

Add the target account and existing active repositories explicitly to the environment tfvars:

```hcl
github_owner = "dceoy"

repositories = {
  "terraform-gh-repos"  = {}
  "another-public-repo" = {}
}
```

Every inventory entry must already exist in the configured `github_owner` account and must not be archived. Terraform reads and imports each repository automatically; a missing or archived repository makes planning fail. Creating repositories through this configuration is intentionally unsupported.

Repository descriptions, website URLs, topics, visibility, and archive state are intentionally left unmanaged and retain their current GitHub values. Terraform manages repository feature and merge settings from inventory defaults/overrides where those settings are available on GitHub Free. Projects, discussions, and wikis default to disabled.

For private repositories on GitHub Free, settings unavailable on that plan are preserved from their observed GitHub values rather than reconciled. In particular, wiki and auto-merge settings are retained for private repositories; public repositories continue to use the inventory defaults/overrides.

Archived repositories are outside the Terraform management scope. Terraform does not preserve or reconcile settings for archived repositories. Before retiring a managed repository, remove its Terraform state bindings without destroying the remote repository and remove it from the inventory; archive it only after Terraform no longer manages it. If a repository is archived externally while it remains in the inventory, the next plan fails instead of attempting to modify the read-only repository.

The default security policy enables Dependabot vulnerability alerts and security updates, gives the default Actions `GITHUB_TOKEN` read-only permissions, and allows GitHub Actions to approve pull requests. Workflows that require write access must request it explicitly at workflow or job scope.

For public repositories, where GitHub Free supports the features, Terraform also enables Code Security, secret scanning, secret-scanning push protection, AI-based secret detection, non-provider secret patterns, and one identical default-branch ruleset per repository. The common ruleset prevents branch deletion and force pushes, requires changes through pull requests with zero mandatory approvals, and requires review threads to be resolved. Private repositories are excluded from ruleset and public-only security configuration.

The `terraform-gh-repos` ruleset was already imported by the configuration that predates this migration, so this configuration does not retain its historical ruleset ID. When onboarding another existing public repository that already has the ruleset Terraform should manage, import that ruleset into `github_repository_ruleset.branch["<repository>"]` once before applying rather than storing its ID in repository inventory.

Review the HCP Terraform plan before applying when first importing an existing repository because Terraform will reconcile its managed GitHub settings while leaving the repository description, website URL, topics, visibility, and archive state unchanged.
