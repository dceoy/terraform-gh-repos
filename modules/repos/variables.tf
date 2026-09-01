variable "github_owner" {
  description = "GitHub account that owns the managed repositories."
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID used for provider authentication. Leave unset to use GITHUB_TOKEN or the provider's normal token/CLI authentication instead."
  type        = string
  default     = null
  validation {
    condition = (
      (
        var.github_app_id == null
        && var.github_app_installation_id == null
        && var.github_app_pem_file == null
      )
      || (
        var.github_app_id != null
        && length(trimspace(var.github_app_id)) > 0
        && var.github_app_installation_id != null
        && length(trimspace(var.github_app_installation_id)) > 0
        && var.github_app_pem_file != null
        && length(trimspace(var.github_app_pem_file)) > 0
      )
    )
    error_message = "github_app_id, github_app_installation_id, and github_app_pem_file must be set together with non-empty values, or all be unset."
  }
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

variable "manage_default_branch_repository_rulesets" {
  description = "Whether this workspace owns the default-branch repository rulesets. Set to false when an organization workspace owns the shared policy."
  type        = bool
  default     = true
}

variable "default_branch_ruleset" {
  description = "Shared default-branch repository ruleset policy."
  type = object({
    name                              = optional(string, "default-branch-protection")
    enforcement                       = optional(string, "active")
    ref_inclusions                    = optional(set(string), ["~DEFAULT_BRANCH"])
    ref_exclusions                    = optional(set(string), [])
    deletion                          = optional(bool, true)
    non_fast_forward                  = optional(bool, true)
    required_linear_history           = optional(bool, false)
    allowed_merge_methods             = optional(set(string), ["merge", "squash", "rebase"])
    dismiss_stale_reviews_on_push     = optional(bool, false)
    require_code_owner_review         = optional(bool, false)
    require_last_push_approval        = optional(bool, false)
    required_approving_review_count   = optional(number, 0)
    required_review_thread_resolution = optional(bool, true)
  })
  default = {}
  validation {
    condition = (
      length(trimspace(var.default_branch_ruleset.name)) > 0
      && contains(["active", "disabled"], var.default_branch_ruleset.enforcement)
      && length(var.default_branch_ruleset.ref_inclusions) > 0
      && alltrue([
        for pattern in setunion(var.default_branch_ruleset.ref_inclusions, var.default_branch_ruleset.ref_exclusions) :
        length(trimspace(pattern)) > 0
      ])
      && length(var.default_branch_ruleset.allowed_merge_methods) > 0
      && alltrue([
        for method in var.default_branch_ruleset.allowed_merge_methods :
        contains(["merge", "squash", "rebase"], method)
      ])
      && var.default_branch_ruleset.required_approving_review_count >= 0
      && var.default_branch_ruleset.required_approving_review_count <= 6
      && floor(var.default_branch_ruleset.required_approving_review_count) == var.default_branch_ruleset.required_approving_review_count
    )
    error_message = "The default branch ruleset must have a non-empty name and ref inclusion, active or disabled enforcement, supported merge methods, and zero to six required approvals."
  }
}

variable "repositories" {
  description = "Repositories tracked by this Terraform configuration. Map keys are stable Terraform identities; retired entries are retained as tombstones but excluded from management."
  type = map(object({
    github_id                        = optional(number)
    ruleset_id                       = optional(number)
    name                             = optional(string)
    observed_visibility              = optional(string)
    retired                          = optional(bool, false)
    has_issues                       = optional(bool, true)
    has_discussions                  = optional(bool, false)
    has_projects                     = optional(bool, false)
    has_wiki                         = optional(bool, false)
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
    security_and_analysis = optional(object({
      code_security                         = optional(string, "enabled")
      secret_scanning                       = optional(string, "enabled")
      secret_scanning_push_protection       = optional(string, "enabled")
      secret_scanning_ai_detection          = optional(string, "enabled")
      secret_scanning_non_provider_patterns = optional(string, "enabled")
    }), {})
  }))
  default = {}
  validation {
    condition = length(distinct([
      for key, repo in var.repositories : coalesce(repo.name, key)
    ])) == length(var.repositories)
    error_message = "Repository names must be unique."
  }
  validation {
    condition = alltrue([
      for key, repo in var.repositories :
      repo.name == null || repo.name == key || !contains(keys(var.repositories), repo.name)
    ])
    error_message = "Repository names must not reuse another stable Terraform key."
  }
  validation {
    condition = length([
      for repo in values(var.repositories) : repo.github_id
      if repo.github_id != null
      ]) == length(distinct([
        for repo in values(var.repositories) : repo.github_id
        if repo.github_id != null
    ]))
    error_message = "GitHub repository IDs must be unique when set."
  }
  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      repo.ruleset_id == null || (repo.ruleset_id > 0 && floor(repo.ruleset_id) == repo.ruleset_id)
    ])
    error_message = "Ruleset IDs must be positive integers when set."
  }
  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      repo.name == null || length(trimspace(repo.name)) > 0
    ])
    error_message = "Repository names must not be empty when set."
  }
  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      repo.observed_visibility == null || contains(["public", "private", "internal"], repo.observed_visibility)
    ])
    error_message = "Observed repository visibility must be public, private, or internal when set."
  }
  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      !repo.retired || repo.github_id != null
    ])
    error_message = "Retired repository tombstones require github_id."
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
      !repo.dependabot_security_updates || repo.vulnerability_alerts
    ])
    error_message = "Dependabot security updates require vulnerability alerts to be enabled."
  }
  validation {
    condition = alltrue([
      for repo in values(var.repositories) : alltrue([
        for status in [
          repo.security_and_analysis.code_security,
          repo.security_and_analysis.secret_scanning,
          repo.security_and_analysis.secret_scanning_push_protection,
          repo.security_and_analysis.secret_scanning_ai_detection,
          repo.security_and_analysis.secret_scanning_non_provider_patterns,
        ] : contains(["enabled", "disabled"], status)
      ])
    ])
    error_message = "Repository security and analysis statuses must be enabled or disabled."
  }
  validation {
    condition = alltrue([
      for repo in values(var.repositories) :
      repo.security_and_analysis.secret_scanning_push_protection == "disabled"
      || repo.security_and_analysis.secret_scanning == "enabled"
    ])
    error_message = "Secret scanning must be enabled when secret scanning push protection is enabled."
  }
}
