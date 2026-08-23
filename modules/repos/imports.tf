import {
  for_each = var.repositories

  to = github_repository.this[each.key]
  id = each.key
}

import {
  for_each = local.active_repositories

  to = github_workflow_repository_permissions.this[each.key]
  id = each.key
}

# Adopt the existing ruleset while moving ruleset policy out of repository inventory.
import {
  for_each = {
    for name, repo in local.public_repositories : name => repo
    if name == "terraform-gh-repos"
  }

  to = github_repository_ruleset.default_branch[each.key]
  id = "${each.key}:20934253"
}
