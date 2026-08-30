output "organization_id" {
  description = "GitHub numeric organization ID."
  value       = data.github_organization.current.id
}

output "organization_ruleset_id" {
  description = "The managed organization default-branch ruleset ID, or null when no ruleset is configured."
  value       = try(github_organization_ruleset.branch["default"].ruleset_id, null)
}
