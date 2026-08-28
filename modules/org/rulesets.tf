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
