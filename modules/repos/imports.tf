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
    for name, repo in var.repositories : name => repo
    if repo.ruleset.enabled && repo.ruleset.id != null
  }

  to = github_repository_ruleset.default_branch[each.key]
  id = "${each.key}:${each.value.ruleset.id}"
}
