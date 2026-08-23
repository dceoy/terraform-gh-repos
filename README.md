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

Create a VCS-driven workspace with:

- VCS repository: `dceoy/terraform-gh-repos`
- Terraform working directory: `modules/repos`
- Execution mode: Remote

Store GitHub App credentials as Terraform variables on the workspace: `github_app_id`, `github_app_installation_id`, and `github_app_pem_file` (the PEM file contents, including newlines). Mark only `github_app_pem_file` as sensitive; the app and installation IDs are identifiers, not secrets. The provider uses GitHub App authentication only when all three are set; otherwise it uses `GITHUB_TOKEN` or the provider's normal token/CLI authentication. These must be Terraform variables, not environment variables — the module reads them itself and passes them into the `github` provider's `app_auth` block.

For GitHub App authentication, grant the app repository `Administration: Read and write` and `Contents: Read and write` permissions. Administration covers repository settings, rulesets, vulnerability alerts, and workflow-permission reconciliation; Contents is required for merge-setting reconciliation.

Do not set `GITHUB_OWNER`; the owner is configured by the Terraform variable `github_owner`.

## Repository inventory

Add repositories explicitly to `modules/repos/repositories.auto.tfvars`:

```hcl
repositories = {
  "terraform-gh-repos" = {
    description     = "Manage GitHub repositories with Terraform"
    visibility      = "public"
    import_existing = true

    ruleset = {
      enabled = true
      id      = 20934253
    }
  }
}
```

Existing repositories default to `import_existing = true`. Set it to `false` when Terraform should create a new repository. Existing repository workflow permissions are imported automatically; for an existing ruleset, set `ruleset.id` so Terraform imports it instead of creating a second ruleset.

Set `visibility` explicitly for every inventory entry, including repositories being imported, to avoid changing a private repository's visibility unintentionally.

The default repository policy enables Issues, Projects, Wiki, merge/squash/rebase merging, auto-merge, branch updates, deletion of merged branches, and vulnerability alerts. It grants read and write permissions to the default `GITHUB_TOKEN` and allows GitHub Actions to approve pull requests. Repository rulesets are enabled by default and protect the default branch from deletion and force pushes, require changes through pull requests with zero mandatory approvals, allow merge/squash/rebase, and do not require linear history or review-thread resolution.

Review the HCP Terraform plan before applying when first importing an existing repository because Terraform will reconcile its current GitHub settings with the declared policy.
