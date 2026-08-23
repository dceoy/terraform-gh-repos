import {
  for_each = {
    for name, repo in var.repositories : name => repo
    if repo.import_existing
  }

  to = github_repository.this[each.key]
  id = each.key
}

import {
  for_each = {
    for name, repo in local.active_repositories : name => repo
    if repo.import_existing
  }

  to = github_workflow_repository_permissions.this[each.key]
  id = each.key
}

# Adopt the existing ruleset while moving ruleset policy out of repository inventory.
import {
  to = github_repository_ruleset.default_branch["terraform-gh-repos"]
  id = "terraform-gh-repos:20934253"
}
