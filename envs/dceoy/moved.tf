moved {
  from = data.github_repository.existing
  to   = module.repos.data.github_repository.existing
}

moved {
  from = github_repository.repo
  to   = module.repos.github_repository.repo
}

moved {
  from = github_repository_vulnerability_alerts.alerts
  to   = module.repos.github_repository_vulnerability_alerts.alerts
}

moved {
  from = github_repository_dependabot_security_updates.dependabot
  to   = module.repos.github_repository_dependabot_security_updates.dependabot
}

moved {
  from = github_workflow_repository_permissions.actions
  to   = module.repos.github_workflow_repository_permissions.actions
}

moved {
  from = github_repository_ruleset.branch
  to   = module.repos.github_repository_ruleset.branch
}
