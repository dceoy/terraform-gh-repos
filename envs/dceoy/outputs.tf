output "repository_names" {
  description = "Names of repositories managed by Terraform."
  value       = module.repos.repository_names
}

output "ruleset_ids" {
  description = "GitHub ruleset IDs keyed by repository name."
  value       = module.repos.ruleset_ids
}
