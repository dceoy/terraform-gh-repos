data "github_repository" "existing" {
  for_each  = var.repositories
  full_name = "${var.github_owner}/${each.key}"
  lifecycle {
    postcondition {
      condition     = !self.archived
      error_message = "Archived repository ${each.key} is outside Terraform management scope."
    }
  }
}

resource "github_repository" "repo" {
  #checkov:skip=CKV_GIT_1:Managed repositories may intentionally be public; visibility is preserved from GitHub.
  #checkov:skip=CKV2_GIT_1:Ruleset-based branch protection is applied uniformly to public repositories supported by GitHub Free.
  for_each               = var.repositories
  name                   = each.key
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
    for_each = contains(keys(local.public_repositories), each.key) ? [true] : []
    content {
      code_security {
        status = "enabled"
      }
      secret_scanning {
        status = "enabled"
      }
      secret_scanning_push_protection {
        status = "enabled"
      }
      secret_scanning_ai_detection {
        status = "enabled"
      }
      secret_scanning_non_provider_patterns {
        status = "enabled"
      }
    }
  }
  lifecycle {
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
  for_each   = var.repositories
  repository = github_repository.repo[each.key].name
  enabled    = each.value.vulnerability_alerts
}

resource "github_repository_dependabot_security_updates" "dependabot" {
  for_each   = var.repositories
  repository = github_repository.repo[each.key].name
  enabled    = each.value.dependabot_security_updates
  depends_on = [github_repository_vulnerability_alerts.alerts]
}

resource "github_workflow_repository_permissions" "actions" {
  for_each                         = var.repositories
  repository                       = github_repository.repo[each.key].name
  default_workflow_permissions     = each.value.default_workflow_permissions
  can_approve_pull_request_reviews = each.value.can_approve_pull_request_reviews
}

resource "github_repository_ruleset" "branch" {
  for_each    = local.public_repositories
  name        = "default-branch-protection"
  repository  = github_repository.repo[each.key].name
  target      = "branch"
  enforcement = "active"
  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }
  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = false
    pull_request {
      allowed_merge_methods             = ["merge", "squash", "rebase"]
      dismiss_stale_reviews_on_push     = false
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 0
      required_review_thread_resolution = true
    }
  }
}
