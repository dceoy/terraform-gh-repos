data "github_organization" "current" {
  name         = var.github_owner
  summary_only = true
}

resource "github_organization_settings" "settings" {
  billing_email                           = var.organization_settings.billing_email
  default_repository_permission           = var.organization_settings.default_repository_permission
  has_organization_projects               = var.organization_settings.has_organization_projects
  has_repository_projects                 = var.organization_settings.has_repository_projects
  members_can_create_repositories         = var.organization_settings.members_can_create_repositories
  members_can_create_public_repositories  = var.organization_settings.members_can_create_public_repositories
  members_can_create_private_repositories = var.organization_settings.members_can_create_private_repositories
  members_can_create_pages                = var.organization_settings.members_can_create_pages
  members_can_create_public_pages         = var.organization_settings.members_can_create_public_pages
  members_can_create_private_pages        = var.organization_settings.members_can_create_private_pages
  members_can_fork_private_repositories   = var.organization_settings.members_can_fork_private_repositories
  web_commit_signoff_required             = var.organization_settings.web_commit_signoff_required

  lifecycle {
    destroy = false
    ignore_changes = [
      company,
      email,
      twitter_username,
      location,
      name,
      description,
      blog,
      members_can_create_internal_repositories,
      advanced_security_enabled_for_new_repositories,
      dependabot_alerts_enabled_for_new_repositories,
      dependabot_security_updates_enabled_for_new_repositories,
      dependency_graph_enabled_for_new_repositories,
      secret_scanning_enabled_for_new_repositories,
      secret_scanning_push_protection_enabled_for_new_repositories,
    ]
  }
}
