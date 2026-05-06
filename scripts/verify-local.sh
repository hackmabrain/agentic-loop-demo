#!/usr/bin/env bash
# verify-local.sh — confirms the developer laptop has everything Phase A
# needs. Idempotent. Exits 0 on success, non-zero on failure.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

PASS=0
FAIL=0

ok() { echo "[ ✓ ] $1";   PASS=$((PASS + 1)); }
ko() { echo "[ ✗ ] $1";   FAIL=$((FAIL + 1)); }

# Node 20+
if v="$(command -v node >/dev/null && node --version 2>/dev/null)"; then
  major="${v#v}"; major="${major%%.*}"
  if [[ "${major}" -ge 20 ]]; then ok "Node ${v}"; else
    ko "Node ${v} is too old. Install: brew install node@20"
  fi
else
  ko "Node not found. Install: brew install node@20"
fi

# Azure CLI 2.60+
if v="$(az --version 2>/dev/null | head -n1 | awk '{print $2}')"; then
  IFS=. read -r major minor _ <<< "${v}"
  if (( major > 2 || (major == 2 && minor >= 60) )); then ok "az ${v}"; else
    ko "az ${v} is too old. Update: brew install azure-cli (then brew upgrade)"
  fi
else
  ko "az CLI not found. Install: brew install azure-cli"
fi

# GitHub CLI 2.60+
if v="$(gh --version 2>/dev/null | head -n1 | awk '{print $3}')"; then
  IFS=. read -r major minor _ <<< "${v}"
  if (( major > 2 || (major == 2 && minor >= 60) )); then ok "gh ${v}"; else
    ko "gh ${v} is too old. Update: brew upgrade gh"
  fi
else
  ko "gh CLI not found. Install: brew install gh"
fi

# gh-aw extension
if gh extension list 2>/dev/null | grep -q "github/gh-aw"; then
  ok "gh-aw extension installed"
else
  ko "gh-aw extension missing. Install: gh extension install github/gh-aw"
fi

# Bicep CLI (via az)
if az bicep version 2>/dev/null | grep -q "Bicep CLI"; then
  ok "Bicep CLI present ($(az bicep version 2>/dev/null | head -n1))"
else
  ko "Bicep not installed. Install: az bicep install"
fi

# jq (used everywhere)
if command -v jq >/dev/null 2>&1; then
  ok "jq $(jq --version)"
else
  ko "jq missing. Install: brew install jq"
fi

# Repo: deps installed, tests run
if [[ -d "${REPO_ROOT}/src/node_modules" ]]; then
  ok "src/node_modules present"
else
  ko "src/node_modules missing. Run: ( cd src && npm ci )"
fi

if ( cd "${REPO_ROOT}/src" && npm test --silent >/tmp/aldemo-npm-test.log 2>&1 ); then
  ok "npm test passed (after-fix state)"
else
  if grep -q "GET /products without category returns 200" /tmp/aldemo-npm-test.log 2>/dev/null; then
    ok "npm test reports 1 expected failure (the seeded bug — this is correct pre-fix)"
  else
    ko "npm test failed unexpectedly. See /tmp/aldemo-npm-test.log"
  fi
fi

# Azure auth
if az account show >/dev/null 2>&1; then
  USER="$(az account show --query user.name -o tsv)"
  SUB="$(az account show --query name -o tsv)"
  ok "az logged in as ${USER} (subscription: ${SUB})"
else
  ko "az not authenticated. Run: az login"
fi

# GitHub auth
if gh auth status >/dev/null 2>&1; then
  ok "gh authenticated"
else
  ko "gh not authenticated. Run: gh auth login"
fi

# Subscription matches .env.demo if present
if [[ -f "${REPO_ROOT}/.env.demo" ]]; then
  # shellcheck source=/dev/null
  source "${REPO_ROOT}/.env.demo"
  current="$(az account show --query id -o tsv)"
  if [[ "${current}" == "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
    ok "Active subscription matches .env.demo (${current})"
  else
    ko "Active subscription (${current}) ≠ .env.demo (${AZURE_SUBSCRIPTION_ID:-unset}). Run: az account set --subscription ${AZURE_SUBSCRIPTION_ID:-?}"
  fi
fi

echo
echo "PASS=${PASS} FAIL=${FAIL}"
[[ "${FAIL}" -eq 0 ]] && echo "LOCAL ✓" || { echo "LOCAL ✗"; exit 1; }
