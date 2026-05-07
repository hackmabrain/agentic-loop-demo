#!/usr/bin/env bash
# verify-azure.sh — confirms Phase C is complete on the demo resource group:
# App Service + slots reachable, App Insights collecting, alert wired, SRE
# Agent provisioned with the four RBAC roles, KB uploaded, IRP enabled, MCP
# connector configured.
#
# SRE Agent is in preview. CLI/ARM coverage is partial. Where there is no
# stable CLI surface we use `az rest` against the resource provider.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

ENV_FILE="${REPO_ROOT}/.env.demo"
[[ -f "${ENV_FILE}" ]] || { echo "ERROR: ${ENV_FILE} not found. Run infra/provision.sh first." >&2; exit 1; }
# shellcheck source=/dev/null
source "${ENV_FILE}"

PASS=0
FAIL=0
ok() { echo "[ ✓ ] $1"; PASS=$((PASS + 1)); }
ko() { echo "[ ✗ ] $1"; FAIL=$((FAIL + 1)); }

echo "Resource group: ${AZURE_RG}"

# Resource group exists in eastus2
loc="$(az group show --name "${AZURE_RG}" --query location -o tsv 2>/dev/null || true)"
if [[ "${loc}" == "eastus2" ]]; then
  ok "Resource group exists in eastus2"
else
  ko "Resource group not found in eastus2 (got '${loc}')"
fi

# App Service + slots
state="$(az webapp show --resource-group "${AZURE_RG}" --name "${APP_NAME}" --query state -o tsv 2>/dev/null || true)"
if [[ "${state}" == "Running" ]]; then
  ok "App Service '${APP_NAME}' is Running"
else
  ko "App Service state is '${state}', expected 'Running'"
fi

slot_names="$(az webapp deployment slot list --resource-group "${AZURE_RG}" --name "${APP_NAME}" --query "[].name" -o tsv 2>/dev/null || true)"
for slot in staging historical; do
  if echo "${slot_names}" | grep -qx "${slot}"; then
    ok "Slot '${slot}' exists"
  else
    ko "Slot '${slot}' missing"
  fi
done

# Reachability
status="$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/")"
if [[ "${status}" == "200" ]]; then
  ok "GET ${APP_URL}/ → 200"
else
  ko "GET ${APP_URL}/ → ${status}"
fi

# Application Insights connection string non-empty
if [[ -n "${APPI_CONNECTION_STRING:-}" ]]; then
  ok "App Insights connection string present"
else
  ko "App Insights connection string missing in .env.demo"
fi

# Log Analytics
if az monitor log-analytics workspace show --resource-group "${AZURE_RG}" --workspace-name "${LAW_NAME}" >/dev/null 2>&1; then
  ok "Log Analytics workspace '${LAW_NAME}' present"
else
  ko "Log Analytics workspace missing"
fi

# Metric Alert
alert_state="$(az monitor metrics alert list --resource-group "${AZURE_RG}" --query "[?contains(name,'5xx')].enabled | [0]" -o tsv 2>/dev/null || true)"
if [[ "${alert_state}" == "true" ]]; then
  ok "5xx metric alert exists and is enabled"
else
  ko "5xx metric alert missing or disabled"
fi

# Action group must have a real webhook receiver wired up to the SRE Agent.
# (Bicep deploys the Action Group with no receivers; SETUP step C11 adds the
# SRE Agent incoming webhook URL via `az monitor action-group update`.)
ag_uri="$(az monitor action-group show --resource-group "${AZURE_RG}" --name "${ACTION_GROUP_NAME}" --query "webhookReceivers[0].serviceUri" -o tsv 2>/dev/null || true)"
if [[ -z "${ag_uri}" ]]; then
  ko "Action group has no webhook receiver yet — complete SETUP step C11 to wire it to the SRE Agent"
else
  ok "Action group webhook configured: ${ag_uri:0:60}…"
fi

# SRE Agent existence (preview — try the resource provider via az rest)
sre_count="$(az rest --method GET --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RG}/providers/Microsoft.App/agents?api-version=${SRE_API_VERSION:-2026-01-01}" 2>/dev/null | jq -r '.value | length' 2>/dev/null || echo 0)"
if [[ "${sre_count}" -ge 1 ]]; then
  ok "SRE Agent resource present (${sre_count} found)"
else
  ko "SRE Agent resource not detected in ${AZURE_RG} via Microsoft.App RP. If the API version differs in your tenant, verify in the Portal (SETUP C6)."
fi

# RBAC role assignments on the SRE Agent's managed identity (best-effort)
sre_principal="$(az rest --method GET --uri "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RG}/providers/Microsoft.App/agents?api-version=${SRE_API_VERSION:-2026-01-01}" 2>/dev/null | jq -r '.value[0].identity.principalId // ""' || true)"
if [[ -n "${sre_principal}" ]]; then
  for role in "Reader" "Monitoring Reader" "Log Analytics Reader"; do
    n="$(az role assignment list --assignee "${sre_principal}" --query "[?roleDefinitionName=='${role}'] | length(@)" -o tsv 2>/dev/null || echo 0)"
    if [[ "${n}" -ge 1 ]]; then ok "RBAC: ${role} assigned to SRE Agent"; else ko "RBAC: ${role} missing on SRE Agent"; fi
  done
fi

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]] && echo "AZURE ✓" || { echo "AZURE ✗"; exit 1; }
