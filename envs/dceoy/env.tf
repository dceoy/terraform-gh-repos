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
  nullable    = false
  validation {
    condition     = length(var.repositories) > 0
    error_message = "Repository inventory must not be empty; load repos.tfvars.json."
  }
}

provider "github" {
  owner = var.github_owner
  dynamic "app_auth" {
    for_each = (
      var.github_app_id != null
      && var.github_app_installation_id != null
      && var.github_app_pem_file != null
    ) ? [1] : []
    content {
      id              = var.github_app_id
      installation_id = var.github_app_installation_id
      pem_file        = var.github_app_pem_file
    }
  }
}

module "repos" {
  source = "../../modules/repos"
  github_owner = var.github_owner
  repositories = var.repositories
}

output "repository_names" {
  description = "Names of repositories managed by Terraform."
  value       = module.repos.repository_names
}

output "ruleset_ids" {
  description = "GitHub ruleset IDs keyed by repository name."
  value       = module.repos.ruleset_ids
}
