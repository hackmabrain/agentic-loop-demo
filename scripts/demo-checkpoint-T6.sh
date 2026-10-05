#!/usr/bin/env bash
# T6 — Trigger the live failure. This is the only checkpoint that ACTS.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

# Fail loud if the demo env wasn't loaded — otherwise the Portal URL would
# silently contain literal "?" characters and open a broken page on stage.
: "${AZURE_TENANT_ID:?run: source .env.demo first (or rerun infra/provision.sh --target demo)}"
: "${AZURE_SUBSCRIPTION_ID:?run: source .env.demo first}"
: "${AZURE_RG:?run: source .env.demo first}"
: "${APP_NAME:?run: source .env.demo first}"

echo ">> Triggering production failure…"
"${SCRIPT_DIR}/trigger-failure.sh"

METRICS_URL="https://portal.azure.com/#@${AZURE_TENANT_ID}/resource/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RG}/providers/Microsoft.Web/sites/${APP_NAME}/metrics"

cp_banner "T6  live failure triggered" "${METRICS_URL}"
cp_open  "${METRICS_URL}"
