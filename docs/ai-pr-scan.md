# GitHub repository governance: free features only

Use the GitHub Terraform provider for supported settings. Do not enable separately billed features through this repository. In particular, `security_and_analysis.secret_scanning_ai_detection` is not AI pull-request scanning.

## Free security features

The existing Terraform module manages vulnerability alerts, Dependabot security updates, repository rulesets and applicable free repository security settings. Preserve these resources instead of duplicating them through `gh api`.

CodeQL on eligible public repositories can use GitHub's free code scanning offering, but confirm eligibility before enabling default setup. No CodeQL API reconciliation is introduced here.

## Excluded paid or uncertain-cost services

AI pull-request scanning, GitHub Copilot cloud agent, and paid GitHub Code Security or Secret Protection entitlements are excluded. Do not run the previous AI scan reconciliation script; it has been removed. Organization-level security configurations are also out of scope for this personal-account inventory.

## GitHub Sponsors

GitHub Sponsors is a funding feature, not a repository security setting. GitHub displays sponsor links using `.github/FUNDING.yml`; this repository already declares:

```yaml
github:
  - dceoy
```

No Terraform or REST API resource is required to publish that funding link. The account must separately be eligible for and enrolled in GitHub Sponsors for the link to work. Existing funding metadata is intentionally left unchanged.
