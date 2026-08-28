locals {
  member_usernames_by_lower = {
    for username in keys(var.members) : lower(username) => username
  }

  members_by_lower = {
    for username, member in var.members : lower(username) => {
      username             = username
      role                 = member.role
      downgrade_on_destroy = member.downgrade_on_destroy
    }
  }

  team_names = {
    for key, team in var.teams : key => team.name
  }

  team_memberships = {
    for membership in flatten([
      for team_key, team in var.teams : [
        for username, member in team.members : {
          key      = "${team_key}:${lower(username)}"
          team_key = team_key
          username = try(local.member_usernames_by_lower[lower(username)], username)
          role     = member.role
        }
      ]
    ]) : membership.key => membership
  }

  team_repositories = {
    for access in flatten([
      for team_key, team in var.teams : [
        for repository, permission in team.repositories : {
          key        = "${team_key}:${lower(repository)}"
          team_key   = team_key
          repository = repository
          permission = permission
        }
      ]
    ]) : access.key => access
  }

  repository_names = setunion(
    toset(flatten([
      for team in values(var.teams) : keys(team.repositories)
    ])),
    var.actions.selected_repositories,
  )

  repository_names_by_lower = {
    for repository_key, repositories in {
      for repository in local.repository_names : lower(repository) => repository...
    } : repository_key => sort(repositories)[0]
  }

  repository_metadata = {
    for repository_key, repository in data.github_rest_api.managed :
    repository_key => jsondecode(repository.body)
  }
}
