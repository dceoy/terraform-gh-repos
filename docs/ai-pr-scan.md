# AI pull-request scanning

GitHub's AI scan for pull requests is currently configured through a dedicated REST API rather than the `github_repository.security_and_analysis` block. The latter's `secret_scanning_ai_detection` is unrelated.

Run the reconciliation script with a GitHub App installation token or user token that has **repository Administration: write** permissions:

```bash
GH_TOKEN=... bash scripts/sync-ai-pr-scan.sh envs/dceoy/repos.tfvars.json
```

To disable instead, pass `disabled` as the second argument.

The script selects only non-retired repositories explicitly observed as public in the inventory. It excludes private repositories and does not modify Terraform state. It is an **imperative reconciliation utility**, not a Terraform-managed resource; changes made outside the script will not be detected by `terraform plan`. API failures stop the script with a nonzero exit status. Verify API availability, account eligibility, and billing before running it across the inventory. Do not store tokens in the repository.
