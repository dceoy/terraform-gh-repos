locals {
  team_names = {
    for key, team in var.teams : key => coalesce(team.name, key)
  }

  team_memberships = {
    for membership in flatten([
      for team_key, team in var.teams : [
        for username, member in team.members : {
          key      = "${team_key}:${username}"
          team_key = team_key
          username = username
          role     = member.role
        }
      ]
    ]) : membership.key => membership
  }

  team_repositories = {
    for access in flatten([
      for team_key, team in var.teams : [
        for repository, permission in team.repositories : {
          key        = "${team_key}:${repository}"
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
}
