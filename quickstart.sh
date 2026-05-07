#!/usr/bin/env bash
# quickstart.sh — one-shot setup for a fresh clone on a new laptop.
#
# Run this ONCE after `git clone` to bring the demo from "fresh checkout"
# to "live on Azure with the seeded-bug 'before' state ready for tomorrow".
# It does five things:
#
#   1. Verifies tools + Azure/GitHub auth + that you're NOT on the
#      personal Free Trial subscription.
#   2. Installs Node deps in src/.
#   3. Provisions the Azure infra (resource group, App Service, AI, LAW,
#      alert, action group) via Bicep — tries eastus2, falls back to
#      swedencentral, then australiaeast on quota errors.
#   4. Out-of-band deploys app.zip via `az webapp deployment source
#      config-zip` (the deploy workflow gates on `npm test` which fails
#      pre-fix because the seeded bug is intentional — we side-load the
#      bug into production for the demo's "before" state).
#   5. Runs reset-demo.sh and prints the live App URL.
#
# Usage:
#   bash quickstart.sh                          # default: hackmabrain repo, eastus2 first
#   bash quickstart.sh --location swedencentral # skip eastus2, start in Sweden
#   bash quickstart.sh --dry-run                # show what would happen, do nothing
#
# After this finishes successfully, you have:
#   - rg-agentic-loop-demo provisioned in Azure (some supported region)
#   - The buggy "before" code deployed (audience sees red error banner on stage)
#   - .env.demo populated with all outputs
#   - GitHub repo secrets populated (AZURE_*) — overwriting any prior values
#
# Manual steps remaining after this:
#   - SRE Agent Portal walkthrough (SETUP.md Phase C6–C11, ~35 min)
#   - Fallback recordings (docs/fallback/README.md, ~20 min)

set -euo pipefail

# -- Defaults --------------------------------------------------------------
GITHUB_REPO="${GITHUB_REPO:-hackmabrain/agentic-loop-demo}"
DRY_RUN=0
USER_LOCATION=""

# Personal Free Trial sub from the previous laptop — refuse to run there.
PERSONAL_SUB_ID="b1229034-5362-455d-ac1c-af0ac10e9d1a"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --location) shift; USER_LOCATION="$1"; ;;
    --location=*) USER_LOCATION="${arg#*=}" ;;
    -h|--help) sed -n '1,32p' "$0"; exit 0 ;;
  esac
  shift 2>/dev/null || true
done

cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$(pwd)"

run() { if (( DRY_RUN )); then echo "  [dry-run] $*"; else eval "$@"; fi }

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
hr()    { printf '%s\n' "================================================================"; }

# -- 1. Pre-flight ---------------------------------------------------------
hr; bold "1/5  pre-flight checks"; hr

fail() { red "ERROR: $*"; exit 1; }

# Tools
for tool in node az gh jq bicep; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool not installed."
done
gh extension list 2>/dev/null | grep -q "github/gh-aw" || fail "gh-aw extension missing — run: gh extension install github/gh-aw"

NODE_MAJOR="$(node --version | sed 's/v\([0-9]*\)\..*/\1/')"
[[ "$NODE_MAJOR" -ge 20 ]] || fail "Node $NODE_MAJOR is too old; need >=20."
echo "  ✓ tools (node $(node --version), $(az --version | head -1 | awk '{print $2}'), $(gh --version | head -1 | awk '{print $3}'))"

# Azure auth
SUB_ID="$(az account show --query id -o tsv 2>/dev/null || echo NONE)"
[[ "$SUB_ID" == "NONE" ]] && fail "az not authenticated. Run: az login"
[[ "$SUB_ID" == "$PERSONAL_SUB_ID" ]] && fail "Active subscription is the personal Free Trial sub. Switch to a work sub: az account set --subscription <work-sub-id>"
SUB_NAME="$(az account show --query name -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
echo "  ✓ az authenticated → $SUB_NAME ($SUB_ID)"

# GitHub auth
gh auth status >/dev/null 2>&1 || fail "gh not authenticated. Run: gh auth login"
GH_USER="$(gh api user --jq .login 2>/dev/null || echo unknown)"
echo "  ✓ gh authenticated as $GH_USER"

# Repo accessibility
gh repo view "$GITHUB_REPO" >/dev/null 2>&1 || fail "Cannot access $GITHUB_REPO. Run: gh auth refresh or check the repo URL."
echo "  ✓ $GITHUB_REPO accessible"

# Repo files
[[ -f infra/main.bicep ]] || fail "infra/main.bicep not found — are you in the cloned repo root?"
[[ -f src/package.json ]] || fail "src/package.json not found — fresh clone may have failed."
echo "  ✓ repo layout looks right"

if (( DRY_RUN )); then
  echo ""; bold "DRY RUN — exiting before any changes."; exit 0
fi

# -- 2. npm ci -------------------------------------------------------------
hr; bold "2/5  installing Node dependencies"; hr
( cd src && npm ci --silent --no-audit --no-fund )
( cd src && npm test 2>&1 | grep -E "^# (pass|fail) " ) || true
echo "  ✓ Node deps installed"

# -- 3. Provision Azure (with region fallback) -----------------------------
hr; bold "3/5  provisioning Azure infrastructure"; hr

REGIONS=("eastus2" "swedencentral" "australiaeast")
[[ -n "$USER_LOCATION" ]] && REGIONS=("$USER_LOCATION" "${REGIONS[@]/$USER_LOCATION}")

PROVISIONED=0
for region in "${REGIONS[@]}"; do
  [[ -z "$region" ]] && continue
  echo ""
  bold ">> Trying region: $region"
  if PYTHONWARNINGS="ignore::SyntaxWarning" \
     GITHUB_REPO="$GITHUB_REPO" \
     LOCATION="$region" \
     bash infra/provision.sh --target demo; then
    PROVISIONED=1
    echo ""
    green "  ✓ provisioned successfully in $region"
    break
  else
    red "  ✗ provisioning failed in $region — trying next region (if any)"
    # If the failure was quota-related, the resource group is empty / clean
    # enough for the next region. If it was something else, the next region
    # also fails and the loop exits with PROVISIONED=0.
  fi
done

if (( ! PROVISIONED )); then
  fail "All three SRE-Agent-supported regions failed. Check Azure portal for quota or capacity issues."
fi

# Load the .env.demo so the rest of the script has the variables.
[[ -f .env.demo ]] || fail ".env.demo not generated — provisioner may have aborted before writing outputs."
# shellcheck source=/dev/null
source .env.demo

# -- 4. Out-of-band deploy (the seeded-bug 'before' state) -----------------
hr; bold "4/5  deploying the seeded-bug 'before' state"; hr

[[ -n "${APP_NAME:-}" ]] || fail "APP_NAME missing from .env.demo"
[[ -n "${APP_URL:-}" ]]  || fail "APP_URL missing from .env.demo"

echo "  app:    $APP_NAME"
echo "  url:    $APP_URL"
echo "  rg:     $AZURE_RG"

ZIP="$(mktemp -d)/app.zip"
( cd src && zip -qr "$ZIP" . -x "tests/*" "*.test.js" "node_modules/*" )
echo "  ✓ packaged $(du -h "$ZIP" | awk '{print $1}') zip"

az webapp deployment source config-zip \
  --resource-group "$AZURE_RG" \
  --name "$APP_NAME" \
  --src "$ZIP" >/dev/null
rm -rf "$(dirname "$ZIP")"
echo "  ✓ deploy submitted, waiting for cold start…"

# Poll / for 200 (HTML serves regardless of /products bug).
for i in $(seq 1 30); do
  STATUS="$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/")"
  if [[ "$STATUS" == "200" ]]; then
    echo "  ✓ $APP_URL/ → 200 (HTML page)"
    break
  fi
  echo "    [$i/30] $APP_URL/ → HTTP $STATUS — waiting 10s for cold start…"
  sleep 10
done
[[ "$STATUS" == "200" ]] || fail "App URL never returned 200. Check Azure Portal → App Service → Log stream."

# Confirm seeded bug is live.
PROD_STATUS="$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/products")"
ELEC_STATUS="$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL/products?category=electronics")"
echo "  ✓ /products            → $PROD_STATUS  (expect 500 — seeded bug is the 'before' state)"
echo "  ✓ /products?cat=elec   → $ELEC_STATUS  (expect 200 — categorized filter works)"

# -- 5. Reset to demo-ready state ------------------------------------------
hr; bold "5/5  resetting to demo-ready state"; hr
bash scripts/reset-demo.sh || echo "  (reset-demo.sh exited non-zero; acceptable if /products still returns 500 in pre-fix state)"

# -- Final report ----------------------------------------------------------
echo ""; hr
green "  PROVISIONED ✓   DEPLOYED ✓   READY (pre-fix) ✓"
hr
cat <<EOF

  App URL:             $APP_URL
  Resource group:      $AZURE_RG  (region: $AZURE_LOCATION)
  GitHub repo:         $GITHUB_REPO

  Live demo states (try each in your browser):
    GET $APP_URL/                          → 200  (catalog page renders)
    GET $APP_URL/products                  → 500  (seeded bug — red banner on page)
    GET $APP_URL/products?category=…       → 200  (categorized filter works)

  Manual steps remaining:
    1. SRE Agent Portal walkthrough — SETUP.md Phase C6–C11 (~35 min)
       Sign in to https://portal.azure.com with your work account.
       Now unblocked since you're on a corporate Entra account.

    2. Fallback recordings — docs/fallback/README.md (~20 min)
       Capture six screen recordings as insurance for tomorrow.

    3. (Optional) Pre-stage the Coding Agent PR — bash scripts/stage-demo.sh
       Removes audience-visible CCA wait time tomorrow.

  Open the live page now to confirm the demo's opening shot:
    open "$APP_URL/"

EOF
