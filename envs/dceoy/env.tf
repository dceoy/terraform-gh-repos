terraform {
  required_version = ">= 1.16.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 6.13.0"
    }
  }
}

variable "github_owner" {
  description = "GitHub account that owns the managed repositories."
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID required for repository provider authentication."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.github_app_id)) > 0
    error_message = "github_app_id must be non-empty."
  }
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID required for repository provider authentication."
  type        = string
  nullable    = false
  validation {
    condition     = length(trimspace(var.github_app_installation_id)) > 0
    error_message = "github_app_installation_id must be non-empty."
  }
}

variable "github_app_pem_file" {
  description = "GitHub App private key (PEM contents) required for repository provider authentication."
  type        = string
  nullable    = false
  sensitive   = true
  validation {
    condition     = length(trimspace(var.github_app_pem_file)) > 0
    error_message = "github_app_pem_file must be non-empty."
  }
}

variable "repositories" {
  description = "Repository inventory passed to the reusable repositories module."
  type        = any
  nullable    = false
  validation {
    condition     = length(var.repositories) > 0
    error_message = "Repository inventory must not be empty; load repos.tfvars.json."
  }
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

provider "github" {
  owner = var.github_owner

  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem_file
  }
}

module "repos" {
  source = "../../modules/repos"

  github_owner                              = var.github_owner
  repositories                              = var.repositories
  manage_default_branch_repository_rulesets = var.manage_default_branch_repository_rulesets
  default_branch_ruleset                    = var.default_branch_ruleset
}

output "repository_names" {
  description = "Names of repositories managed by Terraform."
  value       = module.repos.repository_names
}

output "ruleset_ids" {
  description = "GitHub ruleset IDs keyed by repository name."
  value       = module.repos.ruleset_ids
}
