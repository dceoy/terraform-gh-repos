moved {
  from = github_repository.repo["claude-agent-api"]
  to   = github_repository.repo["casapi"]
}

moved {
  from = github_repository_vulnerability_alerts.alerts["claude-agent-api"]
  to   = github_repository_vulnerability_alerts.alerts["casapi"]
}

moved {
  from = github_repository_dependabot_security_updates.dependabot["claude-agent-api"]
  to   = github_repository_dependabot_security_updates.dependabot["casapi"]
}

moved {
  from = github_workflow_repository_permissions.actions["claude-agent-api"]
  to   = github_workflow_repository_permissions.actions["casapi"]
}

moved {
  from = github_repository_ruleset.branch["claude-agent-api"]
  to   = github_repository_ruleset.branch["casapi"]
}

moved {
  from = github_repository.repo["forex-ai-lab"]
  to   = github_repository.repo["ai-lab"]
}

moved {
  from = github_repository_vulnerability_alerts.alerts["forex-ai-lab"]
  to   = github_repository_vulnerability_alerts.alerts["ai-lab"]
}

moved {
  from = github_repository_dependabot_security_updates.dependabot["forex-ai-lab"]
  to   = github_repository_dependabot_security_updates.dependabot["ai-lab"]
}

moved {
  from = github_workflow_repository_permissions.actions["forex-ai-lab"]
  to   = github_workflow_repository_permissions.actions["ai-lab"]
}

moved {
  from = github_repository_ruleset.branch["forex-ai-lab"]
  to   = github_repository_ruleset.branch["ai-lab"]
}
