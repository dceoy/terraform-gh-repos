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

variable "organization_billing_email" {
  description = "Billing email for the managed GitHub organization."
  type        = string
  sensitive   = true
  validation {
    condition     = length(trimspace(var.organization_billing_email)) > 0
    error_message = "organization_billing_email must not be empty."
  }
}

variable "organization_settings" {
  description = "Organization settings to manage explicitly. All supported Team settings are required so provider defaults cannot change an existing organization during adoption."
  type = object({
    default_repository_permission           = string
    has_organization_projects               = bool
    has_repository_projects                 = bool
    members_can_create_repositories         = bool
    members_can_create_public_repositories  = bool
    members_can_create_private_repositories = bool
    members_can_create_pages                = bool
    members_can_create_public_pages         = bool
    members_can_create_private_pages        = bool
    members_can_fork_private_repositories   = bool
    web_commit_signoff_required             = bool
  })
  validation {
    condition = (
      contains(["read", "write", "admin", "none"], var.organization_settings.default_repository_permission)
    )
    error_message = "default_repository_permission must be read, write, admin, or none."
  }
}

variable "members" {
  description = "Organization members to manage. This map is non-authoritative; members not listed here are not managed."
  type = map(object({
    role                 = string
    downgrade_on_destroy = optional(bool, false)
  }))
  default = {}
  validation {
    condition = (
      alltrue([for username in keys(var.members) : length(trimspace(username)) > 0])
      && length(distinct([for username in keys(var.members) : lower(username)])) == length(var.members)
      && alltrue([for member in values(var.members) : contains(["member", "admin"], member.role)])
    )
    error_message = "Member usernames must be non-empty and case-insensitively unique, and member roles must be member or admin."
  }
}

variable "teams" {
  description = "Teams and their non-authoritative memberships and repository grants, keyed by stable local identity."
  type = map(object({
    team_id              = optional(number)
    name                 = string
    description          = string
    privacy              = string
    notification_setting = string
    parent_team          = string
    members = optional(map(object({
      role = string
    })), {})
    repositories = optional(map(string), {})
  }))
  default = {}
  validation {
    condition = (
      length(distinct([for team in values(var.teams) : coalesce(team.name, "")])) == length(var.teams)
      && length(distinct([for team in values(var.teams) : lower(coalesce(team.name, ""))])) == length(var.teams)
      && alltrue([
        for team in values(var.teams) :
        length(trimspace(coalesce(team.name, ""))) > 0
      ])
    )
    error_message = "Team names must be explicitly configured, non-empty, and case-insensitively unique."
  }
  validation {
    condition = alltrue([
      for team in values(var.teams) : try(
        team.name != null
        && team.description != null
        && team.privacy != null
        && team.notification_setting != null,
        false
      )
    ])
    error_message = "Team name, description, privacy, and notification_setting must be explicitly configured; parent_team may be null."
  }
  validation {
    condition = alltrue([
      for key, team in var.teams :
      team.team_id == null || (team.team_id > 0 && floor(team.team_id) == team.team_id)
    ])
    error_message = "Team IDs must be positive integers when set."
  }
  validation {
    condition = (
      length([for team in values(var.teams) : team.team_id if team.team_id != null])
      == length(distinct([for team in values(var.teams) : team.team_id if team.team_id != null]))
    )
    error_message = "Configured non-null team IDs must be unique."
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
    condition = alltrue([
      for team in values(var.teams) :
      length(distinct([for username in keys(team.members) : lower(username)])) == length(team.members)
    ])
    error_message = "Team membership usernames must be case-insensitively unique within each team."
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
    condition = alltrue([
      for team in values(var.teams) :
      length(distinct([for repository in keys(team.repositories) : lower(repository)])) == length(team.repositories)
    ])
    error_message = "Team repository names must be case-insensitively unique within each team."
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
