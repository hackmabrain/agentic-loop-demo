#!/usr/bin/env bash
# Idempotent provisioner for the Agentic Developer Loop demo.
#
# Usage:
#   bash infra/provision.sh --target rehearsal
#   bash infra/provision.sh --target demo
#   bash infra/provision.sh --target rehearsal --suffix ptmsft01
#
# Behaviour:
#   * Verifies az/bicep are installed.
#   * Selects the right resource group based on --target.
#   * Creates the resource group if absent.
#   * Deploys infra/main.bicep with the parameters file.
#   * Captures every output into ../.env.demo (or .env.rehearsal).
#   * Configures GitHub OIDC federated credentials between the App Service
#     Managed Identity and the GitHub repo (uses gh CLI).
#   * Auto-populates the Variables marker block in QUICK_REFERENCE.md.
#
# Re-runnable: every Azure call is idempotent. Safe to run twice.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

TARGET=""
NAME_SUFFIX="${NAME_SUFFIX:-ptmsft01}"
LOCATION="${LOCATION:-eastus2}"

usage() {
  cat <<EOF
Usage: bash infra/provision.sh --target <rehearsal|demo> [--suffix <token>] [--location <region>]

  --target      rehearsal | demo  (required)
  --suffix      Globally-unique token (default: ${NAME_SUFFIX})
  --location    Azure region      (default: ${LOCATION})

Environment variables (optional):
  GITHUB_REPO   owner/repo for OIDC federated credential (e.g. pavtal/agentic-loop-demo)
  AZURE_SUBSCRIPTION_ID  override the active subscription
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)   TARGET="${2:-}"; shift 2 ;;
    --suffix)   NAME_SUFFIX="${2:-}"; shift 2 ;;
    --location) LOCATION="${2:-}"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown flag: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${TARGET}" ]]; then
  echo "ERROR: --target is required." >&2
  usage; exit 1
fi
if [[ "${TARGET}" != "rehearsal" && "${TARGET}" != "demo" ]]; then
  echo "ERROR: --target must be 'rehearsal' or 'demo'." >&2
  exit 1
fi

RG="rg-agentic-loop-${TARGET}"
ENV_FILE="${REPO_ROOT}/.env.${TARGET}"

# ---- Tool checks ----------------------------------------------------------
command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI is required."; exit 1; }
command -v bicep >/dev/null 2>&1 || az bicep install >/dev/null
command -v gh >/dev/null 2>&1 || echo "WARN: gh CLI not found — OIDC federated credential step will be skipped."

echo ">> Target:        ${TARGET}"
echo ">> Resource group: ${RG}"
echo ">> Region:        ${LOCATION}"
echo ">> Name suffix:   ${NAME_SUFFIX}"

# ---- Subscription ---------------------------------------------------------
if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
fi
SUB_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
echo ">> Subscription:  ${SUB_ID}"
echo ">> Tenant:        ${TENANT_ID}"

# ---- Resource providers ---------------------------------------------------
echo ">> Registering resource providers (idempotent)…"
for ns in Microsoft.Web Microsoft.Insights Microsoft.OperationalInsights Microsoft.ManagedIdentity; do
  state="$(az provider show --namespace "${ns}" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")"
  if [[ "${state}" != "Registered" ]]; then
    az provider register --namespace "${ns}" --wait >/dev/null
  fi
done

# ---- Resource group -------------------------------------------------------
if ! az group show --name "${RG}" >/dev/null 2>&1; then
  echo ">> Creating resource group ${RG}…"
  az group create --name "${RG}" --location "${LOCATION}" --tags workload=agentic-loop-demo target="${TARGET}" >/dev/null
else
  echo ">> Resource group ${RG} already exists."
fi

# ---- Bicep deployment -----------------------------------------------------
DEPLOY_NAME="aldemo-${TARGET}-$(date +%s)"
echo ">> Deploying infra/main.bicep (${DEPLOY_NAME})…"

DEPLOY_OUT="$(az deployment group create \
  --resource-group "${RG}" \
  --name "${DEPLOY_NAME}" \
  --template-file "${SCRIPT_DIR}/main.bicep" \
  --parameters "${SCRIPT_DIR}/main.parameters.json" \
  --parameters nameSuffix="${NAME_SUFFIX}" location="${LOCATION}" \
  --query 'properties.outputs' \
  -o json)"

# ---- Extract outputs ------------------------------------------------------
APP_NAME="$(echo "${DEPLOY_OUT}" | jq -r '.appServiceName.value')"
APP_URL="$(echo "${DEPLOY_OUT}" | jq -r '.appServiceUrl.value')"
APPI_CONN="$(echo "${DEPLOY_OUT}" | jq -r '.appInsightsConnectionString.value')"
APPI_NAME="$(echo "${DEPLOY_OUT}" | jq -r '.appInsightsName.value')"
LAW_ID="$(echo "${DEPLOY_OUT}" | jq -r '.logAnalyticsWorkspaceId.value')"
LAW_NAME="$(echo "${DEPLOY_OUT}" | jq -r '.logAnalyticsName.value')"
AG_ID="$(echo "${DEPLOY_OUT}" | jq -r '.actionGroupId.value')"
AG_NAME="$(echo "${DEPLOY_OUT}" | jq -r '.actionGroupName.value')"
SITE_PRINCIPAL="$(echo "${DEPLOY_OUT}" | jq -r '.sitePrincipalId.value')"

# ---- Write .env.<target> --------------------------------------------------
echo ">> Writing ${ENV_FILE}"
cat > "${ENV_FILE}" <<EOF
# Auto-generated by infra/provision.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Target: ${TARGET}
AZURE_SUBSCRIPTION_ID=${SUB_ID}
AZURE_TENANT_ID=${TENANT_ID}
AZURE_RG=${RG}
AZURE_LOCATION=${LOCATION}
APP_NAME=${APP_NAME}
APP_URL=${APP_URL}
APPI_CONNECTION_STRING=${APPI_CONN}
APPI_NAME=${APPI_NAME}
LAW_ID=${LAW_ID}
LAW_NAME=${LAW_NAME}
ACTION_GROUP_ID=${AG_ID}
ACTION_GROUP_NAME=${AG_NAME}
SITE_PRINCIPAL_ID=${SITE_PRINCIPAL}
# Bump in one place if the preview API version drifts.
SRE_API_VERSION=2026-01-01
EOF

# Symlink the demo env to .env.demo as the canonical one.
if [[ "${TARGET}" == "demo" ]]; then
  cp "${ENV_FILE}" "${REPO_ROOT}/.env.demo.canonical"
fi

# ---- GitHub OIDC federated credentials ------------------------------------
if command -v gh >/dev/null 2>&1 && [[ -n "${GITHUB_REPO:-}" ]]; then
  echo ">> Configuring GitHub OIDC federated credentials for ${GITHUB_REPO}…"

  APP_REGISTRATION_ID="$(az ad app list --display-name "aldemo-deployer-${NAME_SUFFIX}" --query '[0].appId' -o tsv 2>/dev/null || true)"
  if [[ -z "${APP_REGISTRATION_ID}" ]]; then
    APP_REGISTRATION_ID="$(az ad app create --display-name "aldemo-deployer-${NAME_SUFFIX}" --query appId -o tsv)"
    az ad sp create --id "${APP_REGISTRATION_ID}" >/dev/null
  fi

  az role assignment create \
    --assignee "${APP_REGISTRATION_ID}" \
    --role "Contributor" \
    --scope "/subscriptions/${SUB_ID}/resourceGroups/${RG}" >/dev/null 2>&1 || true

  for env in main pull_request production; do
    SUBJECT="repo:${GITHUB_REPO}:ref:refs/heads/main"
    [[ "${env}" == "production" ]] && SUBJECT="repo:${GITHUB_REPO}:environment:production"
    [[ "${env}" == "pull_request" ]] && SUBJECT="repo:${GITHUB_REPO}:pull_request"

    az ad app federated-credential create --id "${APP_REGISTRATION_ID}" --parameters "{
      \"name\": \"github-${env}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"${SUBJECT}\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" >/dev/null 2>&1 || true
  done

  echo "AZURE_CLIENT_ID=${APP_REGISTRATION_ID}" >> "${ENV_FILE}"
  gh secret set AZURE_CLIENT_ID --body "${APP_REGISTRATION_ID}" --repo "${GITHUB_REPO}" >/dev/null
  gh secret set AZURE_TENANT_ID --body "${TENANT_ID}" --repo "${GITHUB_REPO}" >/dev/null
  gh secret set AZURE_SUBSCRIPTION_ID --body "${SUB_ID}" --repo "${GITHUB_REPO}" >/dev/null
fi

# ---- Auto-populate QUICK_REFERENCE.md marker block ------------------------
QR="${REPO_ROOT}/QUICK_REFERENCE.md"
if [[ -f "${QR}" ]]; then
  echo ">> Auto-populating QUICK_REFERENCE.md Variables block…"
  # Quoted heredoc ('PYEOF') stops bash from touching anything inside.
  # Bash variables are passed in as positional args so Python sees only
  # Python syntax. Avoids the bash-vs-Python "bad substitution" trap.
  python3 - "${QR}" "${TARGET}" \
    "${SUB_ID}" "${TENANT_ID}" "${RG}" \
    "${APP_URL}" "${APP_NAME}" "${APPI_NAME}" "${LAW_NAME}" "${AG_NAME}" <<'PYEOF' || \
    echo "   WARN: QUICK_REFERENCE.md auto-populate failed — non-fatal, continuing."
import re, sys, pathlib
(qr_path, target, sub_id, tenant_id, rg, app_url, app_name, appi_name, law_name, ag_name) = (
    pathlib.Path(sys.argv[1]),
    sys.argv[2],
    sys.argv[3], sys.argv[4], sys.argv[5],
    sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9], sys.argv[10],
)
target_upper = target.upper()
text = qr_path.read_text()
block = f"""<!-- AUTO:VARS:{target}:START -->
AZURE_SUBSCRIPTION_ID = {sub_id}
AZURE_TENANT_ID       = {tenant_id}
AZURE_RG_{target_upper}     = {rg}
APP_URL               = {app_url}
APP_NAME              = {app_name}
APPI_NAME             = {appi_name}
LAW_NAME              = {law_name}
ACTION_GROUP_NAME     = {ag_name}
<!-- AUTO:VARS:{target}:END -->"""
pattern = rf"<!-- AUTO:VARS:{target}:START -->.*?<!-- AUTO:VARS:{target}:END -->"
new = re.sub(pattern, block, text, flags=re.DOTALL)
qr_path.write_text(new)
print(f"   updated {qr_path}")
PYEOF
fi

cat <<EOF

=============================================================================
DONE — ${TARGET} provisioning complete.
=============================================================================
App URL:           ${APP_URL}
Resource group:    ${RG}
App Insights:      ${APPI_NAME}
Action group:      ${AG_NAME}

Outputs persisted to: ${ENV_FILE}

Remaining MANUAL steps (cannot be automated, require Azure Portal):
  1. SETUP step C6  — Provision Azure SRE Agent in eastus2 (Portal walkthrough).
  2. SETUP step C7  — Grant SRE Agent RBAC roles (CLI snippets in SETUP.md).
  3. SETUP step C8  — Upload docs/http-5xx-runbook.md to SRE Agent Knowledge Base.
  4. SETUP step C9  — Create the Incident Response Plan.
  5. SETUP step C10 — Configure GitHub MCP connector with a separate PAT.
  6. SETUP step C11 — Replace the action group webhook placeholder URL with
     the SRE Agent incoming webhook (CLI snippet in SETUP.md).

Run the verifier once you complete C6–C11:
  bash scripts/verify-azure.sh
=============================================================================
EOF
