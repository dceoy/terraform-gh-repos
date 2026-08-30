import {
  to = github_organization_settings.settings
  id = data.github_organization.current.id
}

import {
  to = github_actions_organization_permissions.permissions
  id = var.github_owner
}

import {
  to = github_actions_organization_workflow_permissions.permissions
  id = var.github_owner
}

import {
  for_each = var.default_branch_ruleset == null || var.default_branch_ruleset.ruleset_id == null ? {} : {
    default = var.default_branch_ruleset
  }
  to = github_organization_ruleset.adopted_default_branch[each.key]
  id = tostring(each.value.ruleset_id)
}
