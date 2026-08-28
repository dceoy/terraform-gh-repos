resource "github_membership" "member" {
  for_each = local.members_by_lower

  username             = each.value.username
  role                 = each.value.role
  downgrade_on_destroy = each.value.downgrade_on_destroy
}
