#!/usr/bin/env bash
# Triggers the live demo failure that the Azure SRE Agent diagnoses.
#
# Single-slot mode: the Free Trial subscription only has quota for Basic
# (B1) tier App Service plans, which don't support deployment slots. The
# trigger sets INJECT_ERROR=1 directly on the production slot and restarts
# it. Within ~30–60 seconds, /products starts returning 500 and the
# metric alert fires.
#
# Usage:
#   bash scripts/trigger-failure.sh
#   bash scripts/trigger-failure.sh --target rehearsal
#
# **Run once per rehearsal.** Always follow with `scripts/reset-demo.sh`
# before re-arming. The script has a guard at the top: if production is
# already in the failed state (INJECT_ERROR=1), it exits cleanly with a
# message instead of trying to fire again.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

TARGET="demo"
[[ "${1:-}" == "--target" ]] && TARGET="${2:-demo}"

ENV_FILE="${REPO_ROOT}/.env.${TARGET}"
[[ -f "${ENV_FILE}" ]] || { echo "ERROR: ${ENV_FILE} not found. Run infra/provision.sh first."; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

echo ">> Target:        ${TARGET}"
echo ">> Resource group: ${AZURE_RG}"
echo ">> App:           ${APP_NAME}"

# Guard: refuse to fire if production is already in the failed state.
PROD_INJECT="$(az webapp config appsettings list \
  --resource-group "${AZURE_RG}" \
  --name "${APP_NAME}" \
  --query "[?name=='INJECT_ERROR'].value | [0]" -o tsv 2>/dev/null || echo "0")"
if [[ "${PROD_INJECT}" == "1" ]]; then
  echo "STOP: production already has INJECT_ERROR=1 (failure already armed/fired)."
  echo "      Run: bash scripts/reset-demo.sh --target ${TARGET}"
  echo "      Then re-run this script."
  exit 1
fi

echo ">> Setting INJECT_ERROR=1 on production…"
az webapp config appsettings set \
  --resource-group "${AZURE_RG}" \
  --name "${APP_NAME}" \
  --settings INJECT_ERROR=1 >/dev/null

echo ">> Restarting App Service to pick up the new setting…"
az webapp restart --resource-group "${AZURE_RG}" --name "${APP_NAME}"

echo ">> Polling /products to confirm 500s…"
URL="${APP_URL}/products?category=electronics"
for i in $(seq 1 12); do
  STATUS="$(curl -s -o /dev/null -w "%{http_code}" "${URL}")"
  echo "   [$i/12] ${URL} → HTTP ${STATUS}"
  if [[ "${STATUS}" == "500" ]]; then
    echo ">> 500s confirmed. Azure Monitor will fire the 5xx alert within 1–2 minutes."
    break
  fi
  sleep 5
done

cat <<EOF

=============================================================================
Failure injected. Expected next steps:
  ~ 60–120 sec: Metric Alert "alert-5xx-aldemo-*" transitions to Fired
  ~ 90–180 sec: Action Group → SRE Agent webhook fires
  ~ 2–4 min:    SRE Agent investigation thread visible in dashboard
  ~ 3–5 min:    SRE Agent files an issue in the GitHub repo (loop closes)

To roll back:
  bash scripts/reset-demo.sh --target ${TARGET}
=============================================================================
EOF
