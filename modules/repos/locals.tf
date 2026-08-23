locals {
  active_repositories = {
    for name, repo in var.repositories : name => repo
    if !repo.archived
  }

  public_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if !var.repositories[name].archived && existing.visibility == "public"
  }
}
