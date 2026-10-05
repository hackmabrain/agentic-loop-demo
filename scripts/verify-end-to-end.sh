#!/usr/bin/env bash
# verify-end-to-end.sh — full demo dry-run.
#
# Run this Wednesday morning, Wednesday afternoon, and Thursday morning to
# confirm the demo will work. Walks the full loop: cold-open issue, bug
# report, slot swap, alert, SRE Agent investigation, loop-close issue.
#
# Idempotent. Cleans up its own test artifacts (issues created during this
# run are auto-closed by the daily-status workflow's close-older-issues
# safe-output, and the slot is reset).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

ENV_FILE="${REPO_ROOT}/.env.demo"
[[ -f "${ENV_FILE}" ]] || { echo "ERROR: ${ENV_FILE} not found." >&2; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

GITHUB_REPO="${GITHUB_REPO:?must be set in .env.demo or env}"

PASS=0
FAIL=0
ok() { echo "[ ✓ ] $1"; PASS=$((PASS + 1)); }
ko() { echo "[ ✗ ] $1"; FAIL=$((FAIL + 1)); }

step() { echo; echo "── $1 ──"; }

# 1. /products on production returns 200 (post-fix expected state)
step "1/6  GET /products → 200 (post-fix state)"
status="$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/products")"
[[ "${status}" == "200" ]] && ok "/products returns 200" || ko "/products returned ${status}"

# 2. /products?category=electronics returns 200
step "2/6  GET /products?category=electronics → 200"
status="$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/products?category=electronics")"
[[ "${status}" == "200" ]] && ok "/products?category=electronics returns 200" || ko "got ${status}"

# 3. Trigger daily-status workflow, poll until it produces an issue
step "3/6  daily-status creates an issue"
before="$(gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --json number --jq 'length')"
gh workflow run daily-status.lock.yml --repo "${GITHUB_REPO}" >/dev/null
deadline=$((SECONDS + 90))
while (( SECONDS < deadline )); do
  after="$(gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --json number --jq 'length')"
  if (( after > before )); then ok "daily-status issue created"; break; fi
  sleep 5
done
(( after > before )) || ko "daily-status did not produce a new issue within 90 sec"

# 4. trigger-failure → 500s in production
step "4/6  trigger-failure produces 500s on /products"
"${SCRIPT_DIR}/trigger-failure.sh" >/tmp/aldemo-tf.log 2>&1 || ko "trigger-failure.sh failed (see /tmp/aldemo-tf.log)"
deadline=$((SECONDS + 90))
ok500=false
while (( SECONDS < deadline )); do
  status="$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/products")"
  if [[ "${status}" == "500" ]]; then ok500=true; ok "/products returns 500 after slot swap"; break; fi
  sleep 5
done
${ok500} || ko "/products did not return 500 within 90 sec"

# 5. Azure Monitor alert fires
step "5/6  Azure Monitor 5xx alert fires"
deadline=$((SECONDS + 240))
fired=false
while (( SECONDS < deadline )); do
  state="$(az monitor metrics alert list --resource-group "${AZURE_RG}" --query "[?contains(name,'5xx')].alertState | [0]" -o tsv 2>/dev/null || true)"
  if [[ "${state}" == "Fired" || "${state}" == "Firing" || "${state}" == "Activated" ]]; then
    fired=true; ok "Alert state: ${state}"; break
  fi
  echo "   waiting on alert (current state: ${state:-pending})…"
  sleep 15
done
${fired} || ko "Alert did not fire within 4 min"

# 6. SRE Agent files an issue (or test mode confirms an active investigation)
step "6/6  SRE Agent loop close (looks for sre-agent labelled issue)"
# 8-min budget: under cloud-side load (Azure Monitor batching, action-group
# deduplication, SRE Agent investigation queueing) this can take 7–10 min
# in May 2026. We split the failure case so the operator can distinguish
# "never fired" from "still investigating".
deadline=$((SECONDS + 480))
saw_issue=false
saw_investigation=false
while (( SECONDS < deadline )); do
  cnt="$(gh issue list --repo "${GITHUB_REPO}" --label sre-agent --state open --json number --jq 'length' 2>/dev/null || echo 0)"
  if [[ "${cnt}" -ge 1 ]]; then saw_issue=true; ok "SRE Agent filed an issue"; break; fi

  # Halfway through, check whether at least an investigation thread exists.
  if (( SECONDS > deadline - 240 )); then
    inv="$(az rest --method GET \
      --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RG}/providers/Microsoft.App/agents?api-version=${SRE_API_VERSION:-2026-01-01}" \
      2>/dev/null | jq -r '[.value[]?.properties.investigationCount // .value[]?.properties.numberOfInvestigations // .value[]?.properties.activeInvestigations // 0] | add // 0' 2>/dev/null || echo 0)"
    if [[ "${inv}" -ge 1 ]]; then saw_investigation=true; fi
  fi

  echo "   polling for SRE Agent issue…"
  sleep 15
done
if ${saw_issue}; then
  : # already reported ok
elif ${saw_investigation}; then
  ko "SRE Agent investigation is in progress (thread visible in Portal) but no GitHub issue yet — open Portal → SRE Agent → Investigations and watch the thread complete."
else
  ko "SRE Agent did not pick up the alert within 8 min — verify Action Group webhook URL (SETUP step C11) and that the Incident Response Plan filter matches the alert (SETUP step C9)."
fi

# Always reset
echo
echo "── cleanup: scripts/reset-demo.sh ──"
"${SCRIPT_DIR}/reset-demo.sh" >/dev/null || true

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]] && echo "END-TO-END ✓" || { echo "END-TO-END ✗"; exit 1; }
