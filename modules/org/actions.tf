resource "github_actions_organization_permissions" "permissions" {
  enabled_repositories = var.actions.enabled_repositories
  allowed_actions      = var.actions.allowed_actions
  sha_pinning_required = var.actions.sha_pinning_required

  dynamic "allowed_actions_config" {
    for_each = var.actions.allowed_actions == "selected" ? [var.actions.allowed_actions_config] : []
    content {
      github_owned_allowed = allowed_actions_config.value.github_owned_allowed
      verified_allowed     = allowed_actions_config.value.verified_allowed
      patterns_allowed     = allowed_actions_config.value.patterns_allowed
    }
  }

  dynamic "enabled_repositories_config" {
    for_each = var.actions.enabled_repositories == "selected" ? [var.actions.selected_repositories] : []
    content {
      repository_ids = [
        for repository in sort(tolist(enabled_repositories_config.value)) :
        local.repository_metadata[lower(repository)].id
      ]
    }
  }

  lifecycle {
    destroy = false
  }
}

resource "github_actions_organization_workflow_permissions" "permissions" {
  organization_slug                = var.github_owner
  default_workflow_permissions     = var.actions.default_workflow_permissions
  can_approve_pull_request_reviews = var.actions.can_approve_pull_request_reviews

  lifecycle {
    destroy = false
  }
}
