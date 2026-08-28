resource "github_team" "team" {
  for_each = var.teams

  name                 = local.team_names[each.key]
  description          = each.value.description
  privacy              = each.value.privacy
  notification_setting = each.value.notification_setting
  parent_team_id = each.value.parent_team == null ? null : (
    var.teams[each.value.parent_team].team_id != null
    ? tostring(var.teams[each.value.parent_team].team_id)
    : github_team.team[each.value.parent_team].id
  )

  lifecycle {
    destroy         = false
    prevent_destroy = true
  }
}
