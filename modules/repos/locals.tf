locals {
  active_repositories = {
    for key, repo in var.repositories : key => repo
    if !repo.retired
  }
  repository_names = {
    for key, repo in local.active_repositories : key => coalesce(repo.name, key)
  }
  public_repositories = {
    for key, existing in data.github_repository.existing : key => local.active_repositories[key]
    if existing.visibility == "public"
  }
}
