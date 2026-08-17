provider "github" {
  owner = var.github_owner

  dynamic "app_auth" {
    for_each = var.github_app_auth ? [true] : []
    content {}
  }
}
