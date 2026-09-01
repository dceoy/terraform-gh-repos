data "github_organization" "current" {
  name         = var.github_owner
  summary_only = true
}

data "github_rest_api" "organization" {
  provider = github.owner
  endpoint = "/orgs/${var.github_owner}"
  lifecycle {
    postcondition {
      condition     = self.code == 200
      error_message = "Organization ${var.github_owner} could not be read."
    }
    postcondition {
      condition     = try(length(trimspace(jsondecode(self.body).billing_email)) > 0, false)
      error_message = "Organization billing email could not be read."
    }
  }
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
  provider                                                 = github.owner
  billing_email                                            = jsondecode(data.github_rest_api.organization.body).billing_email
  default_repository_permission                            = var.organization_settings.default_repository_permission
  has_organization_projects                                = var.organization_settings.has_organization_projects
  has_repository_projects                                  = var.organization_settings.has_repository_projects
  members_can_create_repositories                          = var.organization_settings.members_can_create_repositories
  members_can_create_public_repositories                   = var.organization_settings.members_can_create_public_repositories
  members_can_create_private_repositories                  = var.organization_settings.members_can_create_private_repositories
  members_can_create_pages                                 = var.organization_settings.members_can_create_pages
  members_can_create_public_pages                          = var.organization_settings.members_can_create_public_pages
  members_can_create_private_pages                         = var.organization_settings.members_can_create_private_pages
  members_can_fork_private_repositories                    = var.organization_settings.members_can_fork_private_repositories
  web_commit_signoff_required                              = var.organization_settings.web_commit_signoff_required
  dependency_graph_enabled_for_new_repositories            = var.organization_settings.dependency_graph_enabled_for_new_repositories
  dependabot_alerts_enabled_for_new_repositories           = var.organization_settings.dependabot_alerts_enabled_for_new_repositories
  dependabot_security_updates_enabled_for_new_repositories = var.organization_settings.dependabot_security_updates_enabled_for_new_repositories
  lifecycle {
    destroy = false
    ignore_changes = [
      billing_email,
      company,
      email,
      twitter_username,
      location,
      name,
      description,
      blog,
      members_can_create_internal_repositories,
      advanced_security_enabled_for_new_repositories,
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

resource "github_organization_ruleset" "branch" {
  for_each = var.default_branch_ruleset == null ? {} : {
    default = var.default_branch_ruleset
  }
  name        = each.value.name
  target      = "branch"
  enforcement = each.value.enforcement
  conditions {
    repository_name {
      include = sort(tolist(each.value.repository_inclusions))
      exclude = sort(tolist(each.value.repository_exclusions))
    }
    ref_name {
      include = sort(tolist(each.value.ref_inclusions))
      exclude = sort(tolist(each.value.ref_exclusions))
    }
  }
  rules {
    deletion                = each.value.deletion
    non_fast_forward        = each.value.non_fast_forward
    required_linear_history = each.value.required_linear_history
    pull_request {
      allowed_merge_methods             = sort(tolist(each.value.allowed_merge_methods))
      dismiss_stale_reviews_on_push     = each.value.dismiss_stale_reviews_on_push
      require_code_owner_review         = each.value.require_code_owner_review
      require_last_push_approval        = each.value.require_last_push_approval
      required_approving_review_count   = each.value.required_approving_review_count
      required_review_thread_resolution = each.value.required_review_thread_resolution
    }
  }
  lifecycle {
    destroy = false
    ignore_changes = [
      bypass_actors,
      conditions[0].repository_name[0].protected,
      rules[0].creation,
      rules[0].update,
      rules[0].required_signatures,
      rules[0].pull_request[0].required_reviewers,
      rules[0].copilot_code_review,
      rules[0].required_status_checks,
      rules[0].commit_message_pattern,
      rules[0].commit_author_email_pattern,
      rules[0].committer_email_pattern,
      rules[0].branch_name_pattern,
      rules[0].tag_name_pattern,
      rules[0].required_workflows,
      rules[0].required_code_scanning,
      rules[0].file_path_restriction,
      rules[0].max_file_size,
      rules[0].max_file_path_length,
      rules[0].file_extension_restriction,
    ]
    postcondition {
      condition     = each.value.ruleset_id == null || self.ruleset_id == each.value.ruleset_id
      error_message = "Configured ruleset_id does not match the adopted GitHub ruleset. Rebind state explicitly before changing the adoption ID."
    }
  }
}
