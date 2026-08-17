locals {
  active_repositories = {
    for name, repo in var.repositories : name => repo
    if !repo.archived
  }

  ruleset_repositories = {
    for name, repo in local.active_repositories : name => repo
    if repo.ruleset.enabled
  }
}
