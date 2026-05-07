#!/usr/bin/env bash
# cleanup-personal.sh — tear down the personal-Azure-subscription side of
# the demo. Stops billing on the rg-agentic-loop-demo and rehearsal groups,
# removes the Entra app registration that was created for OIDC federated
# credentials, and clears the local .env files that hold personal sub IDs.
#
# This script is HARDCODED to your personal subscription as a safety
# guard — it refuses to run if `az account show` returns a different
# subscription. That way you cannot accidentally nuke a work or shared
# subscription with this.
#
# Usage:
#   bash cleanup-personal.sh                     # interactive (asks to confirm)
#   bash cleanup-personal.sh --yes               # skip confirmation, run all
#   bash cleanup-personal.sh --dry-run           # show what would happen, do nothing

set -euo pipefail

# -- Hardcoded safety check ------------------------------------------------
# Edit ONLY this line if your personal subscription ID differs.
EXPECTED_SUB_ID="b1229034-5362-455d-ac1c-af0ac10e9d1a"

# -- Resources to remove ---------------------------------------------------
RG_DEMO="rg-agentic-loop-demo"
RG_REHEARSAL="rg-agentic-loop-rehearsal"
RG_BACKUP="rg-agentic-loop-demo-backup"
APP_REG_NAME="aldemo-deployer-ptmsft01"

# -- Args ------------------------------------------------------------------
DRY_RUN=0
SKIP_CONFIRM=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes)     SKIP_CONFIRM=1 ;;
    -h|--help) sed -n '1,18p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

run() {
  if (( DRY_RUN )); then
    echo "  [dry-run] $*"
  else
    eval "$@"
  fi
}

# -- Verify Azure CLI and active subscription ------------------------------
command -v az >/dev/null 2>&1 || { echo "ERROR: az CLI is required."; exit 1; }

ACTIVE_SUB_ID="$(az account show --query id -o tsv 2>/dev/null || echo "NONE")"
ACTIVE_SUB_NAME="$(az account show --query name -o tsv 2>/dev/null || echo "NONE")"

if [[ "$ACTIVE_SUB_ID" == "NONE" ]]; then
  echo "ERROR: az CLI is not authenticated. Run: az login"
  exit 1
fi

if [[ "$ACTIVE_SUB_ID" != "$EXPECTED_SUB_ID" ]]; then
  cat >&2 <<EOF
================================================================
ABORTED — subscription safety check failed.

  Active sub:    $ACTIVE_SUB_NAME ($ACTIVE_SUB_ID)
  Expected sub:  $EXPECTED_SUB_ID

This script will only run against the hardcoded personal subscription.
If you intend to run it against a different one (e.g., your work sub
after the demo), edit the EXPECTED_SUB_ID constant at the top of this
script.

To switch active subscription:
  az account set --subscription "$EXPECTED_SUB_ID"
================================================================
EOF
  exit 1
fi

# -- Show what we're about to do ------------------------------------------
cat <<EOF
================================================================
Cleanup plan — PERSONAL Azure subscription
================================================================
Subscription: $ACTIVE_SUB_NAME
              $ACTIVE_SUB_ID

Will delete (if present):
  ✗ Resource group: $RG_DEMO
  ✗ Resource group: $RG_REHEARSAL
  ✗ Resource group: $RG_BACKUP
  ✗ Entra app registration: $APP_REG_NAME (and its service principal)
  ✗ Local files: .env.demo, .env.rehearsal, .env.demo-backup, .env.demo.canonical

Will NOT touch:
  - Your GitHub repo (hackmabrain/agentic-loop-demo)
  - The repo secrets (the work laptop will overwrite these later)
  - Your Entra tenant or any other Azure subscription
EOF

if (( DRY_RUN )); then
  echo ""
  echo "Mode: DRY RUN — nothing will actually be deleted."
fi

if (( ! SKIP_CONFIRM && ! DRY_RUN )); then
  echo ""
  read -r -p "Type 'yes' to proceed: " ans
  [[ "$ans" == "yes" ]] || { echo "Aborted."; exit 1; }
fi

echo ""

# -- Delete resource groups -----------------------------------------------
for RG in "$RG_DEMO" "$RG_REHEARSAL" "$RG_BACKUP"; do
  if az group show --name "$RG" >/dev/null 2>&1; then
    echo ">> Deleting resource group: $RG (async, no-wait)…"
    run "az group delete --name \"$RG\" --yes --no-wait"
  else
    echo "   skipped: resource group $RG does not exist."
  fi
done

# -- Delete Entra app registration ----------------------------------------
APP_ID="$(az ad app list --display-name "$APP_REG_NAME" --query '[0].appId' -o tsv 2>/dev/null || true)"
if [[ -n "$APP_ID" ]]; then
  echo ">> Deleting Entra app registration: $APP_REG_NAME ($APP_ID)…"
  run "az ad app delete --id \"$APP_ID\""
else
  echo "   skipped: Entra app registration $APP_REG_NAME does not exist."
fi

# -- Local cleanup --------------------------------------------------------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

for f in .env.demo .env.rehearsal .env.demo-backup .env.demo.canonical .env; do
  if [[ -f "$f" ]]; then
    echo ">> Removing local file: $f"
    run "rm -f \"$f\""
  fi
done

# -- Summary --------------------------------------------------------------
cat <<EOF

================================================================
Cleanup complete.

What's gone:
  - Personal Azure resource groups (deletion runs async in the background;
    can take 5-10 min to fully clear from the portal)
  - Entra app registration $APP_REG_NAME
  - Local .env files

What's still there:
  - The GitHub repo at hackmabrain/agentic-loop-demo (untouched)
  - Repo secrets (will be overwritten by work-laptop provision.sh)
  - The application code in this folder

Next steps:
  1. Move to your work laptop
  2. Sign in with your Microsoft work account: \`az login\`
  3. Clone fresh:
       git clone https://github.com/hackmabrain/agentic-loop-demo.git
  4. Hand Claude Code the prompt I gave you earlier and let it run
  5. SRE Agent should provision cleanly on your work tenant
================================================================
EOF
