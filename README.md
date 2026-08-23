# terraform-gh-repos

Terraform configuration for managing repositories in the `dceoy` GitHub personal account with HCP Terraform.

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

Terraform manages only existing repositories declared in `modules/repos/repositories.auto.tfvars`. By default the inventory declares only this `terraform-gh-repos` repository itself, so adopting this repository does not change any other existing GitHub repositories. Repository creation is intentionally out of scope.

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
    ├── repositories.auto.tfvars
    ├── variables.tf
    └── version.tf
```

## HCP Terraform

### GitHub App setup

Create a private GitHub App owned by the `dceoy` personal account:

1. Open **Settings > Developer settings > GitHub Apps > New GitHub App**.
2. Set a unique app name and use this repository URL as the Homepage URL. OAuth callback and setup URLs are not required.
3. Disable **Webhook > Active**; Terraform does not consume GitHub App webhooks.
4. Grant these repository permissions:
   - **Administration: Read and write**
   - **Contents: Read and write**
5. Select **Only on this account** for where the app can be installed, then create the app.
6. Record the **App ID** and generate a private key under **Private keys**. Keep the downloaded PEM private.
7. Open **Install App** and install it on the `dceoy` account. Select **All repositories** if Terraform should manage repositories without updating the installation each time; otherwise select only the repositories Terraform manages.
8. After installation, open the installation settings and record the numeric installation ID from the URL (`/settings/installations/<installation-id>`).

The App ID and installation ID are identifiers, not secrets. The generated PEM private key is a secret and must not be committed to this repository.

### Workspace setup

Create a VCS-driven workspace with:

- VCS repository: `dceoy/terraform-gh-repos`
- Terraform working directory: `modules/repos`
- Execution mode: Remote

Store GitHub App credentials as Terraform variables on the workspace: `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` (the PEM file contents, including newlines). Mark only `github_app_pem_file` as sensitive; the app and installation IDs are identifiers, not secrets. The provider uses GitHub App authentication only when all three are set; otherwise it uses `GITHUB_TOKEN` or the provider's normal token/CLI authentication. These must be Terraform variables, not environment variables — the module reads them itself and passes them into the `github` provider's `app_auth` block.

For GitHub App authentication, grant the app repository `Administration: Read and write` and `Contents: Read and write` permissions. Administration covers the repository settings managed here, rulesets, vulnerability alerts, security settings, and workflow-permission reconciliation. Contents read/write is required for GitHub to expose the merge-related repository settings that Terraform manages.

Do not set `GITHUB_OWNER`; the owner is configured by the Terraform variable `github_owner`.

## Repository inventory

Add existing repositories explicitly to `modules/repos/repositories.auto.tfvars`:

```hcl
repositories = {
  "terraform-gh-repos"  = {}
  "another-public-repo" = {}
}
```

Every inventory entry must already exist in the `dceoy` account. Terraform reads and imports each repository automatically; a missing repository makes planning fail. Creating repositories through this configuration is intentionally unsupported.

Repository descriptions, website URLs, topics, visibility, and archive state are intentionally left unmanaged and retain their current GitHub values. Terraform manages merge methods, auto-merge, update-branch support, and automatic deletion of merged branches from the repository inventory (using the defaults when omitted). Terraform reads visibility and archive state to avoid configuring unsupported features or writing settings to archived repositories.

The default security policy applies Dependabot vulnerability alerts and security updates to active repositories, gives the default Actions `GITHUB_TOKEN` read-only permissions, and allows GitHub Actions to approve pull requests. Workflows that require write access must request it explicitly at workflow or job scope.

For active public repositories, where GitHub Free supports the features, Terraform also enables Code Security, secret scanning, secret-scanning push protection, and one identical default-branch ruleset per repository. The common ruleset prevents branch deletion and force pushes, requires changes through pull requests with zero mandatory approvals, and requires review threads to be resolved. Private and archived repositories are excluded from ruleset and public-only security configuration.

The `terraform-gh-repos` ruleset was already imported by the configuration that predates this migration, so this configuration does not retain its historical ruleset ID. When onboarding another existing public repository that already has the ruleset Terraform should manage, import that ruleset into `github_repository_ruleset.default_branch["<repository>"]` once before applying rather than storing its ID in repository inventory.

Review the HCP Terraform plan before applying when first importing an existing repository because Terraform will reconcile its managed GitHub settings while leaving the repository description, website URL, topics, visibility, and archive state unchanged.
