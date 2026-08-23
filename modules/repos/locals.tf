locals {
  active_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if !existing.archived
  }
  public_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if !existing.archived && existing.visibility == "public"
  }
}
