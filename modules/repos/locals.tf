locals {
  active_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if !existing.archived
  }
  archived_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if existing.archived
  }
  public_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if !existing.archived && existing.visibility == "public"
  }

  repository_settings = {
    for name, repo in var.repositories : name => {
      homepage_url = data.github_repository.existing[name].homepage_url
      topics       = toset(data.github_repository.existing[name].topics)
      has_issues = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].has_issues
      ) : repo.has_issues
      has_discussions = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].has_discussions
      ) : repo.has_discussions
      has_projects = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].has_projects
      ) : repo.has_projects
      has_wiki = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].has_wiki
      ) : repo.has_wiki
    }
  }

  archived_dependabot_security_updates = {
    for name, response in data.github_rest_api.dependabot_security_updates :
    name => response.code == 200 ? jsondecode(response.body).enabled : false
  }

  archived_workflow_repository_permissions = {
    for name, response in data.github_rest_api.workflow_repository_permissions :
    name => jsondecode(response.body)
  }
}
