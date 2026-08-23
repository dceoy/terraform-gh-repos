locals {
  public_repositories = {
    for name, existing in data.github_repository.existing : name => var.repositories[name]
    if existing.visibility == "public"
  }
}
