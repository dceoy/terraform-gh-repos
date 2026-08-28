resource "github_membership" "member" {
  for_each = var.members

  username             = each.key
  role                 = each.value.role
  downgrade_on_destroy = each.value.downgrade_on_destroy
}
