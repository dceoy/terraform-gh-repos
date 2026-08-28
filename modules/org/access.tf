data "github_repository" "managed" {
  for_each  = local.repository_names
  full_name = "${var.github_owner}/${each.value}"

  lifecycle {
    postcondition {
      condition     = !self.archived
      error_message = "Archived repository ${each.value} is outside Organization team access management scope."
    }
  }
}

resource "github_team_membership" "member" {
  for_each = local.team_memberships

  team_id    = github_team.team[each.value.team_key].id
  username   = each.value.username
  role       = each.value.role
  depends_on = [github_membership.member]

  lifecycle {
    precondition {
      condition = (
        contains(keys(var.members), each.value.username)
        && (
          try(var.members[each.value.username].role, "member") != "admin"
          || each.value.role == "maintainer"
        )
      )
      error_message = "Every configured team user must also be configured in members, and organization owners must be team maintainers."
    }
  }
}

resource "github_team_repository" "access" {
  for_each = local.team_repositories

  team_id    = github_team.team[each.value.team_key].id
  repository = data.github_repository.managed[each.value.repository].name
  permission = each.value.permission
}
