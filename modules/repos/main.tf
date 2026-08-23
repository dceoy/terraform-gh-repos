data "github_repository" "existing" {
  for_each  = var.repositories
  full_name = "${var.github_owner}/${each.key}"
}

data "github_rest_api" "dependabot_security_updates" {
  for_each = local.archived_repositories
  endpoint = "repos/${var.github_owner}/${each.key}/automated-security-fixes"
}

data "github_rest_api" "workflow_repository_permissions" {
  for_each = local.archived_repositories
  endpoint = "repos/${var.github_owner}/${each.key}/actions/permissions/workflow"
}

resource "github_repository" "this" {
  #checkov:skip=CKV_GIT_1:Managed repositories may intentionally be public; visibility is preserved from GitHub.
  #checkov:skip=CKV2_GIT_1:Ruleset-based branch protection is applied uniformly to public repositories supported by GitHub Free.
  for_each        = var.repositories
  name            = each.key
  homepage_url    = local.repository_settings[each.key].homepage_url
  topics          = local.repository_settings[each.key].topics
  has_issues      = local.repository_settings[each.key].has_issues
  has_discussions = local.repository_settings[each.key].has_discussions
  has_projects    = local.repository_settings[each.key].has_projects
  has_wiki        = local.repository_settings[each.key].has_wiki
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
    }
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description,
      visibility,
      archived,
      allow_auto_merge,
      allow_merge_commit,
      allow_rebase_merge,
      allow_squash_merge,
      allow_update_branch,
      allow_forking,
      delete_branch_on_merge,
      web_commit_signoff_required,
      has_downloads,
      merge_commit_message,
      merge_commit_title,
      squash_merge_commit_message,
      squash_merge_commit_title,
    ]
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  for_each   = local.active_repositories
  repository = github_repository.this[each.key].name
  enabled    = each.value.vulnerability_alerts
}

resource "github_repository_dependabot_security_updates" "this" {
  for_each   = var.repositories
  repository = github_repository.this[each.key].name
  enabled = contains(keys(local.archived_repositories), each.key) ? (
    local.archived_dependabot_security_updates[each.key]
  ) : each.value.dependabot_security_updates
}

resource "github_workflow_repository_permissions" "this" {
  for_each   = var.repositories
  repository = github_repository.this[each.key].name
  default_workflow_permissions = contains(keys(local.archived_repositories), each.key) ? (
    local.archived_workflow_repository_permissions[each.key].default_workflow_permissions
  ) : each.value.default_workflow_permissions
  can_approve_pull_request_reviews = contains(keys(local.archived_repositories), each.key) ? (
    local.archived_workflow_repository_permissions[each.key].can_approve_pull_request_reviews
  ) : each.value.can_approve_pull_request_reviews
}

resource "github_repository_ruleset" "default_branch" {
  for_each    = local.public_repositories
  name        = "branch-protection"
  repository  = github_repository.this[each.key].name
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
