# GitHub security settings not yet managed by the GitHub Terraform provider

The repository uses `integrations/github` for supported settings. The dedicated AI pull-request scan setting is not the same as `security_and_analysis.secret_scanning_ai_detection`.

## AI pull-request scanning

The script uses the dedicated GitHub REST API and selects only non-retired repositories explicitly marked public in `repos.tfvars.json`. It does not mutate any repository unless `--apply` is supplied.

```bash
bash scripts/sync-ai-pr-scan.sh envs/dceoy/repos.tfvars.json enabled
GH_TOKEN=... bash scripts/sync-ai-pr-scan.sh envs/dceoy/repos.tfvars.json enabled --apply
```

The applying token must have repository Administration: write permission. API failures stop processing. This is **not declarative Terraform management**: no state or drift detection is provided. Account eligibility and billing must be verified before enabling scans. Do not commit credentials.

## Other API-only or partially managed settings

| Feature | GitHub API | Adoption decision |
| --- | --- | --- |
| AI pull-request scanning | `PATCH /repos/{owner}/{repo}/code-scanning/ai-scan` | Manual opt-in reconciliation above |
| CodeQL default setup | `PATCH /repos/{owner}/{repo}/code-scanning/default-setup` | Not automatically enabled: language support, existing workflows and billing require per-repository review |
| Code security configurations | `/orgs/{org}/code-security/configurations` | Organization-only; not applicable to a personal account |
| Copilot cloud agent configuration | GitHub Copilot API | Excluded: availability and API stability require verification |

The GitHub provider already supports repository rulesets, vulnerability alerts, Dependabot security updates, and several secret scanning controls. Keep these in Terraform rather than duplicating them with `gh api`.

Do not run an API reconciliation automatically on each Terraform apply: it would not be tracked by Terraform state. If declarative state management becomes available through a suitable provider, migrate this functionality and remove the script.
