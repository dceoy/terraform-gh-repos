output "repository_names" {
  description = "Names of repositories managed by Terraform."
  value       = sort(keys(github_repository.repo))
}

output "ruleset_ids" {
  description = "GitHub ruleset IDs keyed by repository name."
  value = {
    for name, ruleset in github_repository_ruleset.branch :
    name => ruleset.ruleset_id
  }
}
