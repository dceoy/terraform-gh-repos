provider "github" {
  owner = var.github_owner

  dynamic "app_auth" {
    for_each = var.github_app_auth ? [true] : []
    content {
      # Empty values let the provider resolve GITHUB_APP_* environment variables.
      id              = ""
      installation_id = ""
      pem_file        = ""
    }
  }
}
