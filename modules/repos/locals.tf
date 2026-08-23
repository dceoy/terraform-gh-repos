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
      homepage_url = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].homepage_url
      ) : repo.homepage_url
      topics = contains(keys(local.archived_repositories), name) ? (
        toset(data.github_repository.existing[name].topics)
      ) : repo.topics
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
      allow_merge_commit = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].allow_merge_commit
      ) : repo.allow_merge_commit
      allow_squash_merge = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].allow_squash_merge
      ) : repo.allow_squash_merge
      allow_rebase_merge = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].allow_rebase_merge
      ) : repo.allow_rebase_merge
      allow_auto_merge = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].allow_auto_merge
      ) : repo.allow_auto_merge
      allow_update_branch = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].allow_update_branch
      ) : repo.allow_update_branch
      delete_branch_on_merge = contains(keys(local.archived_repositories), name) ? (
        data.github_repository.existing[name].delete_branch_on_merge
      ) : repo.delete_branch_on_merge
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
