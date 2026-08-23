import {
  for_each = var.repositories
  to       = github_repository.this[each.key]
  id       = each.key
}

import {
  for_each = var.repositories
  to       = github_workflow_repository_permissions.this[each.key]
  id       = each.key
}
