repositories = {
  "terraform-gh-repos" = {
    description = "[WIP] Terraform modules of GitHub repositories"
    visibility  = "public"

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

    archived        = false
    import_existing = true

    ruleset = {
      enabled = true
      id      = 20934253
    }
  }
}
