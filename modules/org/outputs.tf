output "organization_id" {
  description = "GitHub numeric organization ID."
  value       = data.github_organization.current.id
}

output "organization_ruleset_id" {
  description = "The managed organization default-branch ruleset ID, or null when no ruleset is configured."
  value = var.default_branch_ruleset == null ? null : (
    var.default_branch_ruleset.ruleset_id == null
    ? try(github_organization_ruleset.default_branch["default"].ruleset_id, null)
    : try(github_organization_ruleset.adopted_default_branch["default"].ruleset_id, null)
  )
}
