variable "github_owner" {
  description = "GitHub Organization that Terraform manages."
  type        = string
  validation {
    condition     = length(trimspace(var.github_owner)) > 0
    error_message = "github_owner must not be empty."
  }
}

variable "github_app_id" {
  description = "GitHub App ID used for provider authentication. This organization governance root requires explicit App authentication."
  type        = string
  validation {
    condition     = length(trimspace(var.github_app_id)) > 0
    error_message = "github_app_id must be a non-empty GitHub App ID."
  }
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID used for provider authentication. This organization governance root requires explicit App authentication."
  type        = string
  validation {
    condition     = length(trimspace(var.github_app_installation_id)) > 0
    error_message = "github_app_installation_id must be a non-empty GitHub App installation ID."
  }
}

variable "github_app_pem_file" {
  description = "GitHub App private key (PEM contents) used for provider authentication. This organization governance root requires explicit App authentication."
  type        = string
  sensitive   = true
  validation {
    condition     = length(trimspace(var.github_app_pem_file)) > 0
    error_message = "github_app_pem_file must contain a non-empty GitHub App private key."
  }
}

variable "organization_settings" {
  description = "Organization settings intentionally left configurable instead of enforced by the module policy."
  type = object({
    has_organization_projects   = bool
    has_repository_projects     = bool
    web_commit_signoff_required = bool
  })
}

variable "actions" {
  description = "Organization-wide GitHub Actions policy."
  type = object({
    enabled_repositories  = string
    selected_repositories = set(string)
    allowed_actions       = string
    allowed_actions_config = object({
      github_owned_allowed = bool
      verified_allowed     = bool
      patterns_allowed     = set(string)
    })
    sha_pinning_required             = bool
    default_workflow_permissions     = string
    can_approve_pull_request_reviews = bool
  })
  validation {
    condition = try(
      var.actions.enabled_repositories != null
      && var.actions.selected_repositories != null
      && var.actions.allowed_actions != null
      && var.actions.sha_pinning_required != null
      && var.actions.default_workflow_permissions != null
      && var.actions.can_approve_pull_request_reviews != null
      && contains(["all", "none", "selected"], var.actions.enabled_repositories)
      && (
        var.actions.enabled_repositories == "selected"
        ? length(var.actions.selected_repositories) > 0
        : length(var.actions.selected_repositories) == 0
      )
      && alltrue([for repository in var.actions.selected_repositories : length(trimspace(repository)) > 0])
      && length(distinct([for repository in var.actions.selected_repositories : lower(repository)])) == length(var.actions.selected_repositories)
      && contains(["all", "local_only", "selected"], var.actions.allowed_actions)
      && (
        (var.actions.allowed_actions == "selected") == (var.actions.allowed_actions_config != null)
      )
      && var.actions.sha_pinning_required
      && contains(["read", "write"], var.actions.default_workflow_permissions)
      && (
        var.actions.allowed_actions_config == null
        || (
          var.actions.allowed_actions_config.github_owned_allowed != null
          && var.actions.allowed_actions_config.verified_allowed != null
          && var.actions.allowed_actions_config.patterns_allowed != null
          && alltrue([
            for pattern in var.actions.allowed_actions_config.patterns_allowed : length(trimspace(pattern)) > 0
          ])
          && (
            var.actions.allowed_actions != "selected"
            || length(var.actions.allowed_actions_config.patterns_allowed) > 0
          )
        )
    ), false)
    error_message = "Actions must explicitly set all policy values; SHA pinning must be true with provider 6.13.0; selected policies require a non-empty configuration and pattern set; and default workflow permissions must be read or write."
  }
}

variable "default_branch_ruleset" {
  description = "Optional shared organization default-branch ruleset. Enforcement, exclusions, and approval count must be explicit; set enforcement to disabled for the initial adoption apply."
  type = object({
    ruleset_id                      = optional(number)
    enforcement                     = string
    repository_exclusions           = set(string)
    required_approving_review_count = number
  })
  default = null
  validation {
    condition = (
      var.default_branch_ruleset == null
      || (
        (
          var.default_branch_ruleset.ruleset_id == null
          || (
            var.default_branch_ruleset.ruleset_id > 0
            && floor(var.default_branch_ruleset.ruleset_id) == var.default_branch_ruleset.ruleset_id
          )
        )
        && contains(["active", "disabled"], var.default_branch_ruleset.enforcement)
        && var.default_branch_ruleset.required_approving_review_count >= 0
        && var.default_branch_ruleset.required_approving_review_count <= 6
        && floor(var.default_branch_ruleset.required_approving_review_count) == var.default_branch_ruleset.required_approving_review_count
        && alltrue([
          for repository in var.default_branch_ruleset.repository_exclusions : length(trimspace(repository)) > 0
        ])
        && length(distinct([
          for repository in var.default_branch_ruleset.repository_exclusions : lower(repository)
        ])) == length(var.default_branch_ruleset.repository_exclusions)
      )
    )
    error_message = "The default branch ruleset must use a positive integer ID when set, active or disabled enforcement, zero to six approvals, and non-empty repository exclusions."
  }
}
