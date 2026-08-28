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
  for_each = {
    for key, team in var.teams : key => team
    if team.team_id != null
  }
  to = github_team.team[each.key]
  id = tostring(each.value.team_id)
}

import {
  for_each = var.default_branch_ruleset == null || var.default_branch_ruleset.ruleset_id == null ? {} : {
    default = var.default_branch_ruleset
  }
  to = github_organization_ruleset.default_branch[each.key]
  id = tostring(each.value.ruleset_id)
}
