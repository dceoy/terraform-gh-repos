output "repository_names" {
  description = "Names of repositories managed by Terraform."
  value       = sort(values(local.repository_names))
}

output "ruleset_ids" {
  description = "GitHub ruleset IDs keyed by repository name."
  value = {
    for key, ruleset in github_repository_ruleset.branch :
    local.repository_names[key] => ruleset.ruleset_id
  }
}
