output "organization_id" {
  description = "GitHub numeric organization ID."
  value       = data.github_organization.current.id
}

output "team_ids" {
  description = "GitHub team IDs keyed by the configured stable team key."
  value = {
    for key, team in github_team.team : key => team.id
  }
}

output "team_slugs" {
  description = "GitHub team slugs keyed by the configured stable team key."
  value = {
    for key, team in github_team.team : key => team.slug
  }
}

output "organization_ruleset_id" {
  description = "The managed organization default-branch ruleset ID, or null when no ruleset is configured."
  value       = try(github_organization_ruleset.default_branch["default"].ruleset_id, null)
}
