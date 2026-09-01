data "github_repository" "existing" {
  for_each  = local.active_repositories
  full_name = "${var.github_owner}/${local.repository_names[each.key]}"
  lifecycle {
    postcondition {
      condition     = !self.archived
      error_message = "Archived repository ${local.repository_names[each.key]} is outside Terraform management scope."
    }
  }
}

resource "github_repository" "repo" {
  #checkov:skip=CKV_GIT_1:Managed repositories may intentionally be public; visibility is preserved from GitHub.
  #checkov:skip=CKV2_GIT_1:Ruleset-based branch protection is applied uniformly to public repositories supported by GitHub Free.
  for_each               = local.active_repositories
  name                   = local.repository_names[each.key]
  has_issues             = each.value.has_issues
  has_discussions        = each.value.has_discussions
  has_projects           = each.value.has_projects
  has_wiki               = data.github_repository.existing[each.key].visibility == "public" ? each.value.has_wiki : data.github_repository.existing[each.key].has_wiki
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  allow_auto_merge       = data.github_repository.existing[each.key].visibility == "public" ? each.value.allow_auto_merge : data.github_repository.existing[each.key].allow_auto_merge
  allow_update_branch    = each.value.allow_update_branch
  delete_branch_on_merge = each.value.delete_branch_on_merge
  dynamic "security_and_analysis" {
    for_each = contains(keys(local.public_repositories), each.key) ? [each.value.security_and_analysis] : []
    content {
      code_security {
        status = security_and_analysis.value.code_security
      }
      secret_scanning {
        status = security_and_analysis.value.secret_scanning
      }
      secret_scanning_push_protection {
        status = security_and_analysis.value.secret_scanning_push_protection
      }
      secret_scanning_ai_detection {
        status = security_and_analysis.value.secret_scanning_ai_detection
      }
      secret_scanning_non_provider_patterns {
        status = security_and_analysis.value.secret_scanning_non_provider_patterns
      }
    }
  }
  lifecycle {
    destroy         = false
    prevent_destroy = true
    ignore_changes = [
      description,
      homepage_url,
      topics,
      visibility,
      archived,
      allow_forking,
      web_commit_signoff_required,
      has_downloads,
      merge_commit_message,
      merge_commit_title,
      squash_merge_commit_message,
      squash_merge_commit_title,
    ]
  }
}

resource "github_repository_vulnerability_alerts" "alerts" {
  for_each   = local.active_repositories
  repository = github_repository.repo[each.key].name
  enabled    = each.value.vulnerability_alerts
  lifecycle {
    destroy = false
  }
}

resource "github_repository_dependabot_security_updates" "dependabot" {
  for_each   = local.active_repositories
  repository = github_repository.repo[each.key].name
  enabled    = each.value.dependabot_security_updates
  depends_on = [github_repository_vulnerability_alerts.alerts]
  lifecycle {
    destroy = false
  }
}

resource "github_workflow_repository_permissions" "actions" {
  for_each                         = local.active_repositories
  repository                       = github_repository.repo[each.key].name
  default_workflow_permissions     = each.value.default_workflow_permissions
  can_approve_pull_request_reviews = each.value.can_approve_pull_request_reviews
  lifecycle {
    destroy = false
  }
}

resource "github_repository_ruleset" "branch" {
  for_each    = local.ruleset_repositories
  name        = var.default_branch_ruleset.name
  repository  = github_repository.repo[each.key].name
  target      = "branch"
  enforcement = var.default_branch_ruleset.enforcement
  conditions {
    ref_name {
      include = sort(tolist(var.default_branch_ruleset.ref_inclusions))
      exclude = sort(tolist(var.default_branch_ruleset.ref_exclusions))
    }
  }
  rules {
    deletion                = var.default_branch_ruleset.deletion
    non_fast_forward        = var.default_branch_ruleset.non_fast_forward
    required_linear_history = var.default_branch_ruleset.required_linear_history
    pull_request {
      allowed_merge_methods             = sort(tolist(var.default_branch_ruleset.allowed_merge_methods))
      dismiss_stale_reviews_on_push     = var.default_branch_ruleset.dismiss_stale_reviews_on_push
      require_code_owner_review         = var.default_branch_ruleset.require_code_owner_review
      require_last_push_approval        = var.default_branch_ruleset.require_last_push_approval
      required_approving_review_count   = var.default_branch_ruleset.required_approving_review_count
      required_review_thread_resolution = var.default_branch_ruleset.required_review_thread_resolution
    }
  }
  lifecycle {
    destroy = false
  }
}
