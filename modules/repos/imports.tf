import {
  for_each = var.repositories
  to       = github_repository.repo[each.key]
  id       = local.repository_names[each.key]
}

import {
  for_each = var.repositories
  to       = github_workflow_repository_permissions.actions[each.key]
  id       = local.repository_names[each.key]
}
