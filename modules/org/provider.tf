provider "github" {
  # Provider 6.13 checks the deprecated organization setting before owner.
  # Set both from the same required variable so ambient organization/owner
  # environment variables cannot redirect this root to another account.
  owner        = var.github_owner
  organization = var.github_owner
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}
