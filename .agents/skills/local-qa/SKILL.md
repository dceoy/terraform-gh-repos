---
name: local-qa
description: Run local QA including formatting, linting, and security checks for this repository. Use whenever any file has been updated, and install missing QA tools before rerunning.
disable-model-invocation: false
---

# Local QA

Run the local QA script `scripts/qa.sh` in this skill.

## Procedure

- Execute `scripts/qa.sh` whenever this skill is triggered.
- Capture and summarize key output: success or failure, major warnings, and files modified by formatters or safe fixes.
- If the script fails because a required tool is missing, install the missing tool and rerun the script once.
- Prefer the platform package manager and official installation method for required tools: Node.js/npm, uv, shfmt, shellcheck, actionlint, Terraform, TFLint, and Trivy.
- `npx` supplies Prettier and markdownlint-cli2; `uvx` supplies yamllint, zizmor, and Checkov.
- If installation fails or a package manager is unavailable, report exactly what failed and why.
