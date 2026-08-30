locals {
  repository_names_by_lower = {
    for repository_key, repositories in {
      for repository in var.actions.selected_repositories : lower(repository) => repository...
    } : repository_key => sort(repositories)[0]
  }

  repository_metadata = {
    for repository_key, repository in data.github_rest_api.managed :
    repository_key => jsondecode(repository.body)
  }
}
