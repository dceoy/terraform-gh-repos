provider "github" {
  owner = var.github_owner
  dynamic "app_auth" {
    for_each = (
      var.github_app_id != null
      && var.github_app_installation_id != null
      && var.github_app_pem_file != null
    ) ? [1] : []
    content {
      id              = var.github_app_id
      installation_id = var.github_app_installation_id
      pem_file        = var.github_app_pem_file
    }
  }
}
