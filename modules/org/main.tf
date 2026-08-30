data "github_organization" "current" {
  name         = var.github_owner
  summary_only = true
}

data "github_rest_api" "managed" {
  for_each = local.repository_names_by_lower
  endpoint = "/repos/${var.github_owner}/${each.value}"
  lifecycle {
    postcondition {
      condition     = self.code == 200
      error_message = "Repository ${each.value} could not be read from the managed GitHub organization."
    }
    postcondition {
      condition     = try(jsondecode(self.body).archived == false, false)
      error_message = "Archived repository ${each.value} is outside Organization Actions management scope."
    }
  }
}

resource "github_organization_settings" "settings" {
  billing_email                           = var.organization_billing_email
  default_repository_permission           = var.organization_settings.default_repository_permission
  has_organization_projects               = var.organization_settings.has_organization_projects
  has_repository_projects                 = var.organization_settings.has_repository_projects
  members_can_create_repositories         = var.organization_settings.members_can_create_repositories
  members_can_create_public_repositories  = var.organization_settings.members_can_create_public_repositories
  members_can_create_private_repositories = var.organization_settings.members_can_create_private_repositories
  members_can_create_pages                = var.organization_settings.members_can_create_pages
  members_can_create_public_pages         = var.organization_settings.members_can_create_public_pages
  members_can_create_private_pages        = var.organization_settings.members_can_create_private_pages
  members_can_fork_private_repositories   = var.organization_settings.members_can_fork_private_repositories
  web_commit_signoff_required             = var.organization_settings.web_commit_signoff_required
  lifecycle {
    destroy = false
    ignore_changes = [
      company,
      email,
      twitter_username,
      location,
      name,
      description,
      blog,
      members_can_create_internal_repositories,
      advanced_security_enabled_for_new_repositories,
      dependabot_alerts_enabled_for_new_repositories,
      dependabot_security_updates_enabled_for_new_repositories,
      dependency_graph_enabled_for_new_repositories,
      secret_scanning_enabled_for_new_repositories,
      secret_scanning_push_protection_enabled_for_new_repositories,
    ]
  }
}

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

resource "github_organization_ruleset" "default_branch" {
  for_each = var.default_branch_ruleset == null || var.default_branch_ruleset.ruleset_id != null ? {} : {
    default = var.default_branch_ruleset
  }
  name        = "default-branch-protection"
  target      = "branch"
  enforcement = each.value.enforcement
  conditions {
    repository_name {
      include = ["~ALL"]
      exclude = sort(tolist(each.value.repository_exclusions))
    }
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }
  rules {
    deletion         = true
    non_fast_forward = true
    pull_request {
      allowed_merge_methods             = ["merge", "squash", "rebase"]
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = each.value.required_approving_review_count
      required_review_thread_resolution = true
    }
  }
  lifecycle {
    destroy = false
  }
}

resource "github_organization_ruleset" "adopted_default_branch" {
  for_each = var.default_branch_ruleset == null || var.default_branch_ruleset.ruleset_id == null ? {} : {
    default = var.default_branch_ruleset
  }
  name        = "default-branch-protection"
  target      = "branch"
  enforcement = each.value.enforcement
  conditions {
    repository_name {
      include = ["~ALL"]
      exclude = sort(tolist(each.value.repository_exclusions))
    }
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }
  rules {
    deletion         = true
    non_fast_forward = true
    pull_request {
      allowed_merge_methods             = ["merge", "squash", "rebase"]
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = each.value.required_approving_review_count
      required_review_thread_resolution = true
    }
  }
  lifecycle {
    destroy        = false
    ignore_changes = all
    postcondition {
      condition     = self.ruleset_id == each.value.ruleset_id
      error_message = "Configured ruleset_id does not match the adopted GitHub ruleset. Rebind state explicitly before changing the adoption ID."
    }
  }
}
