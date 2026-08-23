variable "github_owner" {
  description = "GitHub personal account that owns the managed repositories."
  type        = string
  default     = "dceoy"
}

variable "github_app_id" {
  description = "GitHub App ID used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
}

variable "github_app_pem_file" {
  description = "GitHub App private key (PEM contents) used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
  sensitive   = true
}

variable "repositories" {
  description = "Existing repositories managed by this Terraform configuration."
  type = map(object({
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
    default_workflow_permissions     = optional(string, "read")
    can_approve_pull_request_reviews = optional(bool, true)
    vulnerability_alerts             = optional(bool, true)
    dependabot_security_updates      = optional(bool, true)
  }))
  default = {}
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
      !repo.dependabot_security_updates || repo.vulnerability_alerts
    ])
    error_message = "Dependabot security updates require vulnerability alerts to be enabled."
  }
}
