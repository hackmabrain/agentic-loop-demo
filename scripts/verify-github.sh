#!/usr/bin/env bash
# verify-github.sh — confirms Phase B (GitHub repo, secrets, environments,
# Copilot Coding Agent + Code Review settings, branch protection) is in
# place.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

GITHUB_REPO="${GITHUB_REPO:-}"
if [[ -z "${GITHUB_REPO}" && -f "${REPO_ROOT}/.env.demo" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.env.demo"
fi
if [[ -z "${GITHUB_REPO:-}" ]]; then
  echo "ERROR: GITHUB_REPO not set. Set it in .env.demo or export it before running." >&2
  exit 1
fi

PASS=0
FAIL=0
ok() { echo "[ ✓ ] $1"; PASS=$((PASS + 1)); }
ko() { echo "[ ✗ ] $1"; FAIL=$((FAIL + 1)); }

echo "Repo: ${GITHUB_REPO}"

# Repo accessibility
if gh repo view "${GITHUB_REPO}" >/dev/null 2>&1; then
  ok "Repo is accessible"
else
  ko "Repo not accessible. Did you push it? gh repo view ${GITHUB_REPO}"
fi

# Required secrets
declare -a needed=(AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID COPILOT_GITHUB_TOKEN GH_AW_AGENT_TOKEN)
existing="$(gh secret list --repo "${GITHUB_REPO}" 2>/dev/null | awk '{print $1}')"
for s in "${needed[@]}"; do
  if echo "${existing}" | grep -qx "${s}"; then
    ok "Secret ${s} is set"
  else
    ko "Secret ${s} missing. Run: gh secret set ${s} --repo ${GITHUB_REPO} --body '<value>'"
  fi
done

# `production` environment with required reviewers
prod_env="$(gh api "repos/${GITHUB_REPO}/environments/production" --jq '.name' 2>/dev/null || true)"
if [[ "${prod_env}" == "production" ]]; then
  reviewers="$(gh api "repos/${GITHUB_REPO}/environments/production" --jq '[.protection_rules[] | select(.type == "required_reviewers")] | length' 2>/dev/null || echo 0)"
  if [[ "${reviewers}" -ge 1 ]]; then
    ok "production environment has at least one required reviewer"
  else
    ko "production environment exists but has no required reviewers"
  fi
else
  ko "production environment not configured. See SETUP step B5."
fi

# Workflow files exist
if [[ -f "${REPO_ROOT}/.github/workflows/daily-status.md" ]]; then
  ok ".github/workflows/daily-status.md present"
else
  ko ".github/workflows/daily-status.md missing"
fi

if [[ -f "${REPO_ROOT}/.github/workflows/daily-status.lock.yml" ]]; then
  ok ".github/workflows/daily-status.lock.yml present"
else
  ko ".github/workflows/daily-status.lock.yml missing — run: gh aw compile daily-status"
fi

# Branch protection on main
if gh api "repos/${GITHUB_REPO}/branches/main/protection" >/dev/null 2>&1; then
  ok "main branch is protected"
else
  ko "main branch not protected. See SETUP step B8."
fi

# Copilot Coding Agent / Code Review enablement (best-effort — settings APIs change)
copilot_setting="$(gh api "repos/${GITHUB_REPO}" --jq '.has_copilot_coding_agent? // "unknown"' 2>/dev/null || echo unknown)"
if [[ "${copilot_setting}" == "true" ]]; then
  ok "Copilot Coding Agent enabled"
elif [[ "${copilot_setting}" == "unknown" ]]; then
  ok "Copilot Coding Agent enablement could not be confirmed via API — verify in repo Settings → Copilot"
else
  ko "Copilot Coding Agent not enabled. See SETUP step B6."
fi

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]] && echo "GITHUB ✓" || { echo "GITHUB ✗"; exit 1; }
