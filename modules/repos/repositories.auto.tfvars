repositories = {
  "terraform-gh-repos" = {
    has_issues      = true
    has_discussions = false
    has_projects    = true
    has_wiki        = true

    allow_merge_commit     = true
    allow_squash_merge     = true
    allow_rebase_merge     = true
    allow_auto_merge       = true
    allow_update_branch    = true
    delete_branch_on_merge = true

    default_workflow_permissions     = "read"
    can_approve_pull_request_reviews = true

    archived        = false
    import_existing = true

    ruleset = {
      enabled = true
      id      = 20934253
      required_status_checks = [
        "Terraform Cloud/dceoy/repo-id-FxBskt5iSBsdxFwJ",
      ]
    }
  }
}
