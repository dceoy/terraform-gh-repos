data "github_rest_api" "managed" {
  for_each = local.repository_names_by_lower
  endpoint = "/repos/${var.github_owner}/${each.value}"

  lifecycle {
    postcondition {
      condition     = self.code == 200
      error_message = "Repository ${each.value} could not be read from the managed GitHub organization."
    }
    postcondition {
      condition     = try(jsondecode(self.body).archived == false, false)
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
        contains(keys(local.member_usernames_by_lower), lower(each.value.username))
        && (
          try(var.members[local.member_usernames_by_lower[lower(each.value.username)]].role, "member") != "admin"
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
  repository = local.repository_metadata[lower(each.value.repository)].name
  permission = each.value.permission
}
