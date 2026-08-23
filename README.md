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

Terraform manages only repositories declared in `modules/repos/repositories.auto.tfvars`. By default the inventory declares only this `terraform-gh-repos` repository itself (imported via `import_existing = true`), so adopting this repository does not change any other existing GitHub repositories.

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
4. Grant only these repository permissions:
   - **Administration: Read and write**
   - **Contents: Read and write**
5. Select **Only on this account** for where the app can be installed, then create the app.
6. Record the **App ID** and generate a private key under **Private keys**. Keep the downloaded PEM private.
7. Open **Install App** and install it on the `dceoy` account. Select **All repositories** if Terraform should manage or create repositories without updating the installation each time; otherwise select only the repositories Terraform manages.
8. After installation, open the installation settings and record the numeric installation ID from the URL (`/settings/installations/<installation-id>`).

The App ID and installation ID are identifiers, not secrets. The generated PEM private key is a secret and must not be committed to this repository.

### Workspace setup

Create a VCS-driven workspace with:

- VCS repository: `dceoy/terraform-gh-repos`
- Terraform working directory: `modules/repos`
- Execution mode: Remote

Store GitHub App credentials as Terraform variables on the workspace: `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` (the PEM file contents, including newlines). Mark only `github_app_pem_file` as sensitive; the app and installation IDs are identifiers, not secrets. The provider uses GitHub App authentication only when all three are set; otherwise it uses `GITHUB_TOKEN` or the provider's normal token/CLI authentication. These must be Terraform variables, not environment variables — the module reads them itself and passes them into the `github` provider's `app_auth` block.

For GitHub App authentication, grant the app repository `Administration: Read and write` and `Contents: Read and write` permissions. Administration covers repository settings, rulesets, vulnerability alerts, security settings, and workflow-permission reconciliation; Contents is required for merge-setting reconciliation.

Do not set `GITHUB_OWNER`; the owner is configured by the Terraform variable `github_owner`.

## Repository inventory

Add repositories explicitly to `modules/repos/repositories.auto.tfvars`:

```hcl
repositories = {
  "terraform-gh-repos" = {
    import_existing = true

    ruleset = {
      enabled = true
      id      = 20934253
    }
  }
}
```

Existing repositories default to `import_existing = true`. Set it to `false` when Terraform should create a new repository. Existing repository workflow permissions are imported automatically; for an existing ruleset, set `ruleset.id` so Terraform imports it instead of creating a second ruleset.

Repository descriptions and visibility are intentionally left unmanaged. Imported repositories retain their current values. Terraform reads the current visibility only to avoid configuring GitHub Free features that are unavailable on private personal repositories. Newly created repositories use GitHub's default public visibility.

The default security policy applies Dependabot vulnerability alerts and security updates to active repositories, gives the default Actions `GITHUB_TOKEN` read-only permissions, and allows GitHub Actions to approve pull requests. Workflows that require write access must request it explicitly at workflow or job scope.

For public repositories, where GitHub Free supports the features, Terraform also enables Code Security, secret scanning, secret-scanning push protection, and the default-branch ruleset. The ruleset prevents branch deletion and force pushes, requires changes through pull requests with zero mandatory approvals, requires review threads to be resolved, and supports optional required status checks. Private repositories on a GitHub Free personal account are excluded from ruleset and public-only security configuration.

Review the HCP Terraform plan before applying when first importing an existing repository because Terraform will reconcile its managed GitHub settings while leaving the repository description and visibility unchanged.
