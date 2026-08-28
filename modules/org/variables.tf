variable "github_owner" {
  description = "GitHub Organization that Terraform manages."
  type        = string
  validation {
    condition     = length(trimspace(var.github_owner)) > 0
    error_message = "github_owner must not be empty."
  }
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

variable "organization_settings" {
  description = "Organization settings to manage. Fields omitted from this object remain unmanaged."
  type = object({
    billing_email                           = string
    default_repository_permission           = optional(string)
    has_organization_projects               = optional(bool)
    has_repository_projects                 = optional(bool)
    members_can_create_repositories         = optional(bool)
    members_can_create_public_repositories  = optional(bool)
    members_can_create_private_repositories = optional(bool)
    members_can_create_pages                = optional(bool)
    members_can_create_public_pages         = optional(bool)
    members_can_create_private_pages        = optional(bool)
    members_can_fork_private_repositories   = optional(bool)
    web_commit_signoff_required             = optional(bool)
  })
  sensitive = true
  validation {
    condition = (
      length(trimspace(var.organization_settings.billing_email)) > 0
      && (
        var.organization_settings.default_repository_permission == null
        || contains(["read", "write", "admin", "none"], var.organization_settings.default_repository_permission)
      )
    )
    error_message = "billing_email must not be empty and default_repository_permission must be read, write, admin, or none when set."
  }
}

variable "members" {
  description = "Organization members to manage. This map is non-authoritative; members not listed here are not managed."
  type = map(object({
    role                 = optional(string, "member")
    downgrade_on_destroy = optional(bool, false)
  }))
  default = {}
  validation {
    condition = (
      alltrue([for username in keys(var.members) : length(trimspace(username)) > 0])
      && alltrue([for member in values(var.members) : contains(["member", "admin"], member.role)])
    )
    error_message = "Member usernames must not be empty and member roles must be member or admin."
  }
}

variable "teams" {
  description = "Teams and their non-authoritative memberships and repository grants, keyed by stable local identity."
  type = map(object({
    team_id              = optional(number)
    name                 = optional(string)
    description          = optional(string)
    privacy              = optional(string, "closed")
    notification_setting = optional(string, "notifications_enabled")
    parent_team          = optional(string)
    members = optional(map(object({
      role = optional(string, "member")
    })), {})
    repositories = optional(map(string), {})
  }))
  default = {}
  validation {
    condition = (
      length(distinct([for key, team in var.teams : coalesce(team.name, key)])) == length(var.teams)
      && alltrue([
        for key, team in var.teams :
        length(trimspace(coalesce(team.name, key))) > 0
      ])
    )
    error_message = "Team names must be non-empty and unique."
  }
  validation {
    condition = alltrue([
      for key, team in var.teams :
      team.team_id == null || (team.team_id > 0 && floor(team.team_id) == team.team_id)
    ])
    error_message = "Team IDs must be positive integers when set."
  }
  validation {
    condition = alltrue([
      for key, team in var.teams :
      team.parent_team == null || (team.parent_team != key && contains(keys(var.teams), team.parent_team))
    ])
    error_message = "parent_team must reference another configured team."
  }
  validation {
    condition = (
      alltrue([
        for team in values(var.teams) :
        team.privacy != "secret" || team.parent_team == null
      ])
      && alltrue([
        for team in values(var.teams) :
        team.parent_team == null || try(var.teams[team.parent_team].privacy, null) != "secret"
      ])
    )
    error_message = "Secret teams cannot be nested or have child teams."
  }
  validation {
    condition = alltrue([
      for team in values(var.teams) : contains(["closed", "secret"], team.privacy)
    ])
    error_message = "Team privacy must be closed or secret."
  }
  validation {
    condition = alltrue([
      for team in values(var.teams) : contains(["notifications_enabled", "notifications_disabled"], team.notification_setting)
    ])
    error_message = "Team notification_setting must be notifications_enabled or notifications_disabled."
  }
  validation {
    condition = alltrue(flatten([
      for team in values(var.teams) : [
        for membership in values(team.members) : contains(["member", "maintainer"], membership.role)
      ]
    ]))
    error_message = "Team membership roles must be member or maintainer."
  }
  validation {
    condition = alltrue(flatten([
      for team in values(var.teams) : [
        for username in keys(team.members) : length(trimspace(username)) > 0
      ]
    ]))
    error_message = "Team membership usernames must not be empty."
  }
  validation {
    condition = alltrue(flatten([
      for team in values(var.teams) : [
        for repository in keys(team.repositories) : length(trimspace(repository)) > 0
      ]
    ]))
    error_message = "Team repository names must not be empty."
  }
  validation {
    condition = alltrue(flatten([
      for team in values(var.teams) : [
        for permission in values(team.repositories) : contains(["pull", "triage", "push", "maintain", "admin"], permission)
      ]
    ]))
    error_message = "Team repository permissions must be pull, triage, push, maintain, or admin."
  }
}

variable "actions" {
  description = "Organization-wide GitHub Actions policy."
  type = object({
    enabled_repositories  = optional(string, "all")
    selected_repositories = optional(set(string), [])
    allowed_actions       = optional(string, "all")
    allowed_actions_config = optional(object({
      github_owned_allowed = bool
      verified_allowed     = optional(bool, false)
      patterns_allowed     = optional(set(string), [])
    }))
    sha_pinning_required             = optional(bool, false)
    default_workflow_permissions     = optional(string, "read")
    can_approve_pull_request_reviews = optional(bool, false)
  })
  validation {
    condition = (
      contains(["all", "none", "selected"], var.actions.enabled_repositories)
      && (
        var.actions.enabled_repositories == "selected"
        ? length(var.actions.selected_repositories) > 0
        : length(var.actions.selected_repositories) == 0
      )
      && alltrue([for repository in var.actions.selected_repositories : length(trimspace(repository)) > 0])
      && contains(["all", "local_only", "selected"], var.actions.allowed_actions)
      && (
        (var.actions.allowed_actions == "selected") == (var.actions.allowed_actions_config != null)
      )
      && contains(["read", "write"], var.actions.default_workflow_permissions)
    )
    error_message = "Actions must use valid repository/action policies; selected policies require the matching non-empty configuration; and default workflow permissions must be read or write."
  }
}

variable "default_branch_ruleset" {
  description = "Optional shared organization default-branch ruleset. Set enforcement to disabled for the initial adoption apply."
  type = object({
    ruleset_id                      = optional(number)
    enforcement                     = optional(string, "disabled")
    repository_exclusions           = optional(set(string), [])
    required_approving_review_count = optional(number, 0)
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
      )
    )
    error_message = "The default branch ruleset must use a positive integer ID when set, active or disabled enforcement, zero to six approvals, and non-empty repository exclusions."
  }
}
