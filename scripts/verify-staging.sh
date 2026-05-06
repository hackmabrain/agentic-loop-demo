#!/usr/bin/env bash
# verify-staging.sh — confirm all eight time points are pre-staged and
# nothing has degraded overnight.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
# shellcheck source=/dev/null
source "${REPO_ROOT}/.env.demo"
GITHUB_REPO="${GITHUB_REPO:?must be set}"

PASS=0
FAIL=0
ok() { echo "[ ✓ ] $1"; PASS=$((PASS + 1)); }
ko() { echo "[ ✗ ] $1 — recovery: $2"; FAIL=$((FAIL + 1)); }

# T0: tag v0-clean exists
git -C "${REPO_ROOT}" rev-parse --verify v0-clean >/dev/null 2>&1 \
  && ok "T0: tag v0-clean exists" \
  || ko "T0: tag v0-clean missing" "git tag v0-clean main && git push origin v0-clean"

# T1: at least one open daily-status issue
n="$(gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --json number --jq 'length' 2>/dev/null || echo 0)"
[[ "${n}" -ge 1 ]] && ok "T1: ${n} daily-status issue(s) open" \
  || ko "T1: no daily-status issue" "gh workflow run daily-status.lock.yml"

# T2: open issue assigned to the Copilot Coding Agent, labelled bug.
# The CLI assignee is `copilot-swe-agent`; some installs accept the
# alias `copilot`. Search for either.
issue2="$(gh issue list --repo "${GITHUB_REPO}" --label bug --state open \
  --search 'assignee:copilot-swe-agent OR assignee:copilot' \
  --json number,title --jq '.[0].number // ""')"
[[ -n "${issue2}" ]] && ok "T2: bug issue #${issue2} assigned to Copilot Coding Agent" \
  || ko "T2: no Copilot-assigned bug" "bash scripts/restage-demo.sh"

# T3: open draft PR from copilot/fix-products-500
pr_state="$(gh pr list --repo "${GITHUB_REPO}" --state open --search 'head:copilot/fix-products-500' --json number,isDraft --jq '.[0] | "\(.number) \(.isDraft)"' 2>/dev/null || echo "")"
if [[ -z "${pr_state}" ]]; then
  ko "T3: no PR on copilot/fix-products-500" "wait for Coding Agent or restage"
else
  read -r pr_num is_draft <<< "${pr_state}"
  if [[ "${is_draft}" == "true" ]]; then
    ok "T3: draft PR #${pr_num} on copilot/fix-products-500"
  else
    ko "T3: PR #${pr_num} is not Draft" "gh pr ready --undo ${pr_num}"
  fi
fi

# T5: production slot returns 200 on /products (post-fix)
status="$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/products?category=electronics")"
[[ "${status}" == "200" ]] && ok "T5: production /products?category=electronics → 200" \
  || ko "T5: production not in fixed state (HTTP ${status})" "bash scripts/reset-demo.sh"

# T6 readiness: staging slot has INJECT_ERROR=1
staging_inject="$(az webapp config appsettings list --resource-group "${AZURE_RG}" --name "${APP_NAME}" --slot staging --query "[?name=='INJECT_ERROR'].value | [0]" -o tsv 2>/dev/null || echo "")"
[[ "${staging_inject}" == "1" ]] && ok "T6 ready: staging slot has INJECT_ERROR=1" \
  || ko "T6 not ready: staging INJECT_ERROR=${staging_inject:-unset}" "az webapp config appsettings set --slot staging --settings INJECT_ERROR=1"

# T6 readiness: production slot does NOT have INJECT_ERROR=1
prod_inject="$(az webapp config appsettings list --resource-group "${AZURE_RG}" --name "${APP_NAME}" --slot production --query "[?name=='INJECT_ERROR'].value | [0]" -o tsv 2>/dev/null || echo "")"
[[ "${prod_inject}" != "1" ]] && ok "T6 ready: production slot has INJECT_ERROR=${prod_inject:-0}" \
  || ko "T6 not ready: production INJECT_ERROR=1 already" "bash scripts/reset-demo.sh"

# T7: rehearsal-group SRE Agent has at least one investigation
reh_env="${REPO_ROOT}/.env.rehearsal"
if [[ -f "${reh_env}" ]]; then
  # shellcheck source=/dev/null
  source <(grep -E '^AZURE_RG=' "${reh_env}")
  reh_rg="${AZURE_RG}"
  # Re-source the demo env so subsequent steps don't lose AZURE_RG.
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.env.demo"

  # Property name on the preview RP has shifted between previews. Try the
  # three names we've seen and fall back to the raw payload if none match,
  # so the operator can read it.
  raw_json="$(az rest --method GET \
    --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${reh_rg}/providers/Microsoft.App/agents?api-version=${SRE_API_VERSION:-2026-01-01}" \
    2>/dev/null || echo '{}')"
  threads="$(echo "${raw_json}" | jq -r '
    .value[0].properties.investigationCount //
    .value[0].properties.numberOfInvestigations //
    .value[0].properties.activeInvestigations //
    0' 2>/dev/null || echo 0)"
  if [[ "${threads}" -ge 1 ]]; then
    ok "T7: rehearsal SRE Agent has ${threads} investigation thread(s)"
  elif [[ "${raw_json}" == "{}" || "${raw_json}" == "" ]]; then
    ko "T7: rehearsal SRE Agent unreachable (preview API may have rev'd)" "verify SRE_API_VERSION in .env.demo, then re-run"
  else
    echo "   raw SRE Agent payload (truncated):"
    echo "${raw_json}" | jq -r '.value[0].properties // {}' | head -20 | sed 's/^/   /'
    ko "T7: rehearsal SRE Agent has no investigations under any known property name" "bash scripts/trigger-failure.sh --target rehearsal"
  fi
fi

# T8: at least one open issue labelled sre-agent in the repo
sre_issue="$(gh issue list --repo "${GITHUB_REPO}" --label sre-agent --state open --json number --jq '.[0].number // ""')"
[[ -n "${sre_issue}" ]] && ok "T8: SRE-Agent-filed issue #${sre_issue} present" \
  || ko "T8: no sre-agent-labelled issue" "wait for SRE Agent to file from rehearsal trigger, or run scripts/trigger-failure.sh --target rehearsal"

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]] && echo "STAGING ✓" || { echo "STAGING ✗"; exit 1; }
