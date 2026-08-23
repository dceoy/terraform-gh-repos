locals {
  active_repositories = {
    for name, repo in var.repositories : name => repo
    if !repo.archived
  }

  existing_public_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if !var.repositories[name].archived && existing.visibility == "public"
  }

  new_public_repositories = {
    for name, repo in local.active_repositories : name => repo
    if !repo.import_existing
  }

  public_repositories = merge(
    local.existing_public_repositories,
    local.new_public_repositories,
  )

  ruleset_repositories = {
    for name, repo in local.public_repositories : name => repo
    if repo.ruleset.enabled
  }
}
