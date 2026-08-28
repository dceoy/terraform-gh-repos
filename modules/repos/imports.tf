import {
  for_each = local.active_repositories
  to       = github_repository.repo[each.key]
  id       = local.repository_names[each.key]
}

import {
  for_each = local.active_repositories
  to       = github_workflow_repository_permissions.actions[each.key]
  id       = local.repository_names[each.key]
}

import {
  for_each = {
    for key, repo in local.ruleset_repositories : key => repo
    if repo.ruleset_id != null
  }
  to = github_repository_ruleset.branch[each.key]
  id = "${local.repository_names[each.key]}:${each.value.ruleset_id}"
}
