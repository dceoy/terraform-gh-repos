variable "github_owner" {
  description = "GitHub personal account that owns the managed repositories."
  type        = string
  default     = "dceoy"
}

variable "github_app_id" {
  description = "GitHub App ID used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
  sensitive   = true
}

variable "github_app_pem_file" {
  description = "GitHub App private key (PEM contents) used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
  sensitive   = true
}

variable "repositories" {
  description = "Repositories managed by this Terraform configuration."
  type = map(object({
    description                      = optional(string, "")
    homepage_url                     = optional(string)
    visibility                       = string
    topics                           = optional(set(string), [])
    has_issues                       = optional(bool, true)
    has_discussions                  = optional(bool, false)
    has_projects                     = optional(bool, true)
    has_wiki                         = optional(bool, true)
    allow_merge_commit               = optional(bool, true)
    allow_squash_merge               = optional(bool, true)
    allow_rebase_merge               = optional(bool, true)
    allow_auto_merge                 = optional(bool, true)
    allow_update_branch              = optional(bool, true)
    delete_branch_on_merge           = optional(bool, true)
    default_workflow_permissions     = optional(string, "write")
    can_approve_pull_request_reviews = optional(bool, false)
    archived                         = optional(bool, false)
    vulnerability_alerts             = optional(bool, true)
    import_existing                  = optional(bool, true)

    ruleset = optional(object({
      enabled                           = optional(bool, true)
      id                                = optional(number)
      enforcement                       = optional(string, "active")
      require_pull_request              = optional(bool, true)
      allowed_merge_methods             = optional(list(string), ["merge", "squash", "rebase"])
      required_approving_review_count   = optional(number, 0)
      dismiss_stale_reviews_on_push     = optional(bool, false)
      require_code_owner_review         = optional(bool, false)
      require_last_push_approval        = optional(bool, false)
      required_review_thread_resolution = optional(bool, false)
      required_linear_history           = optional(bool, false)
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
      contains(["read", "write"], repo.default_workflow_permissions)
    ])
    error_message = "Default workflow permissions must be read or write."
  }

  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      contains(["active", "disabled"], repo.ruleset.enforcement)
    ])
    error_message = "Repository ruleset enforcement must be active or disabled for a personal account."
  }
}
