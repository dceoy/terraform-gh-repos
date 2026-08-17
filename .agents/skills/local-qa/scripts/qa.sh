#!/usr/bin/env bash

set -euox pipefail
cd "$(git rev-parse --show-toplevel)"

# Supply-chain cooldown: avoid resolving/installing packages published within the last N days.
COOLDOWN_DAYS=7
export UV_EXCLUDE_NEWER="${COOLDOWN_DAYS} days"
export NPM_CONFIG_MIN_RELEASE_AGE="${COOLDOWN_DAYS}"
export PNPM_CONFIG_MINIMUM_RELEASE_AGE=$((COOLDOWN_DAYS * 24 * 60))

N_MARKDOWN_FILES=$(git ls-files -- '*.md' '*.mdx' | wc -l)
if [[ "${N_MARKDOWN_FILES}" -gt 0 ]]; then
  npx -y prettier --write './**/*.{md,mdx}'
  if [[ -f .markdownlint-cli2.jsonc ]]; then
    git ls-files -z -- '*.md' '*.mdx' \
      | xargs -0 -t npx -y markdownlint-cli2 --fix --config .markdownlint-cli2.jsonc
  else
    printf '{"config":{"MD013":false,"MD033":false,"MD041":false}}' > .markdownlint-cli2.jsonc
    set +e
    git ls-files -z -- '*.md' '*.mdx' \
      | xargs -0 -t npx -y markdownlint-cli2 --fix --config .markdownlint-cli2.jsonc
    markdownlint_exit_code="${?}"
    set -e
    rm -f .markdownlint-cli2.jsonc
    [[ "${markdownlint_exit_code}" -eq 0 ]] || exit "${markdownlint_exit_code}"
  fi
fi

N_YAML_FILES=$(git ls-files -- '*.yml' '*.yaml' | wc -l)
if [[ "${N_YAML_FILES}" -gt 0 ]]; then
  git ls-files -z -- '*.yml' '*.yaml' \
    | xargs -0 -t uvx yamllint -d '{"extends": "relaxed", "rules": {"line-length": "disable"}}'
fi

N_BASH_FILES=$(git ls-files -- '*.sh' '*.bash' '*.bats' | wc -l)
if [[ "${N_BASH_FILES}" -gt 0 ]]; then
  git ls-files -z -- '*.sh' '*.bash' '*.bats' \
    | xargs -0 -t shfmt --write --indent=2 --binary-next-line --case-indent --space-redirects
  git ls-files -z -- '*.sh' '*.bash' '*.bats' \
    | xargs -0 -t shellcheck
fi

if [[ -d '.github/workflows' ]]; then
  ZIZMOR_PATHS=('.github/workflows')
  [[ -d '.github/actions' ]] && ZIZMOR_PATHS+=('.github/actions')
  uvx zizmor --fix=safe "${ZIZMOR_PATHS[@]}"

  N_WORKFLOW_YAML_FILES=$(git ls-files -- '.github/workflows/**.yml' '.github/workflows/**.yaml' | wc -l)
  if [[ "${N_WORKFLOW_YAML_FILES}" -gt 0 ]]; then
    git ls-files -z -- '.github/workflows/*.yml' '.github/workflows/*.yaml' \
      | xargs -0 -t actionlint
  fi
fi

N_TERRAFORM_FILES=$(git ls-files -- '*.tf' '*.tfvars' '*.hcl' | wc -l)
if [[ "${N_TERRAFORM_FILES}" -gt 0 ]]; then
  terraform fmt -recursive .
  tflint --recursive --chdir=.
fi

if [[ -d '.github/workflows' ]] || [[ "${N_TERRAFORM_FILES}" -gt 0 ]]; then
  uvx checkov --framework=all --output=github_failed_only --directory=.
fi

if [[ "${N_TERRAFORM_FILES}" -gt 0 ]]; then
  trivy filesystem --scanners vuln,secret,misconfig \
    --skip-dirs .terraform \
    --skip-dirs .git \
    .
fi
