resource "github_repository" "this" {
  for_each = var.repositories

  name                   = each.key
  description            = each.value.description
  homepage_url           = each.value.homepage_url
  visibility             = each.value.visibility
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

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_vulnerability_alerts" "this" {
  for_each = local.active_repositories

  repository = github_repository.this[each.key].name
  enabled    = each.value.vulnerability_alerts
}

resource "github_repository_ruleset" "default_branch" {
  for_each = local.ruleset_repositories

  name        = "default-branch"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = each.value.ruleset.enforcement

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = each.value.ruleset.prevent_deletion
    non_fast_forward        = each.value.ruleset.prevent_force_push
    required_linear_history = each.value.ruleset.required_linear_history

    dynamic "pull_request" {
      for_each = each.value.ruleset.require_pull_request ? [true] : []

      content {
        allowed_merge_methods             = each.value.ruleset.allowed_merge_methods
        dismiss_stale_reviews_on_push     = each.value.ruleset.dismiss_stale_reviews_on_push
        require_code_owner_review         = each.value.ruleset.require_code_owner_review
        require_last_push_approval        = each.value.ruleset.require_last_push_approval
        required_approving_review_count   = each.value.ruleset.required_approving_review_count
        required_review_thread_resolution = each.value.ruleset.required_review_thread_resolution
      }
    }
  }
}
