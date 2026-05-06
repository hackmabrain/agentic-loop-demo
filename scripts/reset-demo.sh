#!/usr/bin/env bash
# Restores the demo environment to a known-good state.
#
# Steps:
#   1. Make sure the production slot has INJECT_ERROR=0.
#   2. Make sure the staging slot has INJECT_ERROR=1 (so the trigger script
#      can swap it back into production for the next rehearsal).
#   3. Restart both slots so the new settings take effect.
#   4. Smoke-test /products on production until it returns 200.
#
# Idempotent. Safe to run between rehearsals.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

TARGET="demo"
[[ "${1:-}" == "--target" ]] && TARGET="${2:-demo}"

ENV_FILE="${REPO_ROOT}/.env.${TARGET}"
[[ -f "${ENV_FILE}" ]] || { echo "ERROR: ${ENV_FILE} not found."; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

echo ">> Resetting ${TARGET} (${APP_NAME})…"

az webapp config appsettings set \
  --resource-group "${AZURE_RG}" \
  --name "${APP_NAME}" \
  --slot production \
  --settings INJECT_ERROR=0 >/dev/null

az webapp config appsettings set \
  --resource-group "${AZURE_RG}" \
  --name "${APP_NAME}" \
  --slot staging \
  --settings INJECT_ERROR=1 >/dev/null

echo ">> Restarting production slot…"
az webapp restart --resource-group "${AZURE_RG}" --name "${APP_NAME}" --slot production

echo ">> Restarting staging slot…"
az webapp restart --resource-group "${AZURE_RG}" --name "${APP_NAME}" --slot staging

echo ">> Waiting for /products to return 200 on production…"
URL="${APP_URL}/products?category=electronics"
for i in $(seq 1 24); do
  STATUS="$(curl -s -o /dev/null -w "%{http_code}" "${URL}")"
  echo "   [$i/24] HTTP ${STATUS}"
  if [[ "${STATUS}" == "200" ]]; then
    echo ">> Reset complete."
    exit 0
  fi
  sleep 5
done

echo "WARN: /products did not return 200 after 2 min. Check Azure Portal." >&2
exit 1
