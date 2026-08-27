locals {
  repository_names = {
    for key, repo in var.repositories : key => coalesce(repo.name, key)
  }
  public_repositories = {
    for key, existing in data.github_repository.existing : key => var.repositories[key]
    if existing.visibility == "public"
  }
}
