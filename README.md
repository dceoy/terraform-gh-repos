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

Terraform manages only repositories declared in `modules/repos/repositories.auto.tfvars`. The inventory is empty by default so adopting this repository does not change existing GitHub repositories.

## Layout

```text
.
├── .github/
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── workflows/
│       └── ci.yml
└── modules/
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

Store GitHub credentials as sensitive workspace environment variables. The provider uses GitHub App authentication when `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and `GITHUB_APP_PEM_FILE` are configured; otherwise it uses `GITHUB_TOKEN` or the provider's normal token/CLI authentication.

For GitHub App authentication, grant the app repository `Administration: Read and write` and `Contents: Read and write` permissions. Administration covers repository settings, rulesets, and vulnerability alerts; Contents is required for merge-setting reconciliation.

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
    }
  }
}
```

Existing repositories default to `import_existing = true`. Set it to `false` when Terraform should create a new repository.

Set `visibility` explicitly for every inventory entry, including repositories being imported, to avoid changing a private repository's visibility unintentionally.

The default repository policy enables Issues, squash/rebase merging, auto-merge, branch updates, deletion of merged branches, and vulnerability alerts. Repository rulesets are opt-in and, when enabled, protect the default branch from deletion and force pushes, require linear history, and require changes through pull requests with zero mandatory approvals.

Review the HCP Terraform plan before applying when first importing an existing repository because Terraform will reconcile its current GitHub settings with the declared policy.
