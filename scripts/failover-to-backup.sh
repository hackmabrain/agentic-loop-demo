#!/usr/bin/env bash
# Cold-standby regional failover. Use only if eastus2 is degraded the morning
# of the talk and the primary demo group is unreachable.
#
# Steps:
#   1. Create rg-agentic-loop-demo-backup in swedencentral if absent.
#   2. Deploy infra/main-backup.bicep.
#   3. Push the latest src/ as a zip to the backup App Service.
#   4. Smoke-test, then write .env.demo-backup with the new endpoints.
#
# Target runtime: 5 minutes. Can be run while Pavan is still walking to the
# stage. Most of the wait is App Service plan provisioning.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

NAME_SUFFIX="${NAME_SUFFIX:-ptmsft01bk}"
LOCATION="${LOCATION:-swedencentral}"
RG="rg-agentic-loop-demo-backup"

command -v az >/dev/null || { echo "ERROR: az CLI required."; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq required."; exit 1; }

echo ">> Creating ${RG} (idempotent)…"
az group create --name "${RG}" --location "${LOCATION}" --tags workload=agentic-loop-demo role=backup >/dev/null

echo ">> Deploying main-backup.bicep…"
DEPLOY_OUT="$(az deployment group create \
  --resource-group "${RG}" \
  --name "aldemo-backup-$(date +%s)" \
  --template-file "${SCRIPT_DIR}/../infra/main-backup.bicep" \
  --parameters nameSuffix="${NAME_SUFFIX}" location="${LOCATION}" \
  --query 'properties.outputs' \
  -o json)"

APP_NAME="$(echo "${DEPLOY_OUT}" | jq -r '.appServiceName.value')"
APP_URL="$(echo "${DEPLOY_OUT}" | jq -r '.appServiceUrl.value')"
APPI_CONN="$(echo "${DEPLOY_OUT}" | jq -r '.appInsightsConnectionString.value')"

echo ">> Packaging src/ for deploy…"
TMPZIP="$(mktemp -d)/app.zip"
( cd "${REPO_ROOT}/src" && zip -qr "${TMPZIP}" . -x "tests/*" "*.test.js" "node_modules/*" )

echo ">> Deploying app to backup site (${APP_NAME})…"
az webapp deployment source config-zip \
  --resource-group "${RG}" \
  --name "${APP_NAME}" \
  --src "${TMPZIP}" >/dev/null

echo ">> Writing .env.demo-backup…"
cat > "${REPO_ROOT}/.env.demo-backup" <<EOF
AZURE_RG=${RG}
APP_NAME=${APP_NAME}
APP_URL=${APP_URL}
APPI_CONNECTION_STRING=${APPI_CONN}
EOF

echo ">> Smoke-testing backup site…"
for i in $(seq 1 24); do
  STATUS="$(curl -s -o /dev/null -w "%{http_code}" "${APP_URL}/")"
  echo "   [$i/24] HTTP ${STATUS}"
  if [[ "${STATUS}" == "200" ]]; then
    echo
    echo "BACKUP READY at: ${APP_URL}"
    echo "Update docs/presenter/quick-reference.md APP_URL before going on stage."
    exit 0
  fi
  sleep 10
done

echo "ERROR: backup site did not respond in time." >&2
exit 1
