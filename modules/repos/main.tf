data "github_repository" "existing" {
  for_each  = var.repositories
  full_name = "${var.github_owner}/${each.key}"
}

resource "github_repository" "this" {
  #checkov:skip=CKV_GIT_1:Managed repositories may intentionally be public; visibility is preserved from GitHub.
  #checkov:skip=CKV2_GIT_1:Ruleset-based branch protection is applied uniformly to public repositories supported by GitHub Free.
  for_each               = var.repositories
  name                   = each.key
  homepage_url           = each.value.homepage_url
  topics                 = each.value.topics
  has_issues             = each.value.has_issues
  has_discussions        = each.value.has_discussions
  has_projects           = each.value.has_projects
  has_wiki               = each.value.has_wiki
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  allow_auto_merge       = each.value.allow_auto_merge
  allow_update_branch    = each.value.allow_update_branch
  delete_branch_on_merge = each.value.delete_branch_on_merge
  archived               = each.value.archived
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
    ignore_changes  = [description, visibility]
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  for_each   = local.active_repositories
  repository = github_repository.this[each.key].name
  enabled    = each.value.vulnerability_alerts
}

resource "github_repository_dependabot_security_updates" "this" {
  for_each   = local.active_repositories
  repository = github_repository.this[each.key].name
  enabled    = each.value.dependabot_security_updates
}

resource "github_workflow_repository_permissions" "this" {
  for_each                         = local.active_repositories
  repository                       = github_repository.this[each.key].name
  default_workflow_permissions     = each.value.default_workflow_permissions
  can_approve_pull_request_reviews = each.value.can_approve_pull_request_reviews
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
