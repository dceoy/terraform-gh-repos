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

variable "repositories" {
  description = "Repository inventory passed to the reusable repositories module."
  type        = any
  default     = {}
}

variable "manage_default_branch_repository_rulesets" {
  description = "Whether repository-level default branch rulesets are managed."
  type        = bool
  default     = true
}

variable "default_branch_ruleset" {
  description = "Default branch ruleset configuration forwarded to the module."
  type        = any
  default     = {}
}
