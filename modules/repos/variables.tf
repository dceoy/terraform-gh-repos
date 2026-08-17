variable "github_owner" {
  description = "GitHub personal account that owns the managed repositories."
  type        = string
  default     = "dceoy"
}

variable "github_app_auth" {
  description = "Use GitHub App authentication from GITHUB_APP_* environment variables instead of token/CLI authentication."
  type        = bool
  default     = false
}

variable "repositories" {
  description = "Repositories managed by this Terraform configuration."
  type = map(object({
    description           = optional(string, "")
    homepage_url           = optional(string)
    visibility             = optional(string, "public")
    topics                 = optional(set(string), [])
    has_issues             = optional(bool, true)
    has_discussions        = optional(bool, false)
    has_projects           = optional(bool, false)
    has_wiki               = optional(bool, false)
    allow_merge_commit     = optional(bool, false)
    allow_squash_merge     = optional(bool, true)
    allow_rebase_merge     = optional(bool, true)
    allow_auto_merge       = optional(bool, true)
    allow_update_branch    = optional(bool, true)
    delete_branch_on_merge = optional(bool, true)
    archived               = optional(bool, false)
    vulnerability_alerts   = optional(bool, true)
    import_existing        = optional(bool, true)

    ruleset = optional(object({
      enabled                           = optional(bool, false)
      id                                = optional(number)
      enforcement                       = optional(string, "active")
      require_pull_request              = optional(bool, true)
      allowed_merge_methods             = optional(list(string), ["squash", "rebase"])
      required_approving_review_count   = optional(number, 0)
      dismiss_stale_reviews_on_push     = optional(bool, false)
      require_code_owner_review         = optional(bool, false)
      require_last_push_approval        = optional(bool, false)
      required_review_thread_resolution = optional(bool, true)
      required_linear_history           = optional(bool, true)
      prevent_deletion                  = optional(bool, true)
      prevent_force_push                = optional(bool, true)
    }), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      contains(["public", "private"], repo.visibility)
    ])
    error_message = "Repository visibility must be public or private."
  }

  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      contains(["active", "disabled"], repo.ruleset.enforcement)
    ])
    error_message = "Repository ruleset enforcement must be active or disabled for a personal account."
  }
}
