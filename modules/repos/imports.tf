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

import {
  for_each = {
    for name, repo in local.ruleset_repositories : name => repo
    if repo.ruleset.id != null
  }

  to = github_repository_ruleset.default_branch[each.key]
  id = "${each.key}:${each.value.ruleset.id}"
}
