module "repos" {
  source = "../../modules/repos"

  github_owner                              = var.github_owner
  repositories                              = var.repositories
  manage_default_branch_repository_rulesets = var.manage_default_branch_repository_rulesets
  default_branch_ruleset                    = var.default_branch_ruleset
}
