#!/usr/bin/env bash
# restage-demo.sh — between-rehearsal reset.
#
# Closes the previous rehearsal's bug + PR + status issue, restores the
# slot configuration to clean state, and then re-runs stage-demo.sh.
# Use after every dress rehearsal.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
# shellcheck source=/dev/null
source "${REPO_ROOT}/.env.demo"
GITHUB_REPO="${GITHUB_REPO:?must be set}"

step() { echo; echo "── $1 ──"; }

step "Reset Azure slots"
"${SCRIPT_DIR}/reset-demo.sh"

step "Close stale issues + PRs"
# Close ONLY the demo's canonical bug issue ("Catalog API returning 500s
# on /products"). We constrain by exact title match so this script never
# carpet-bombs a real bug issue if the repo is reused for anything else.
DEMO_BUG_TITLE='Catalog API returning 500s on /products'
gh issue list --repo "${GITHUB_REPO}" \
  --search "in:title \"${DEMO_BUG_TITLE}\"" \
  --state open \
  --json number --jq '.[].number' \
  | xargs -I{} gh issue close --repo "${GITHUB_REPO}" {} --comment "Reset for next rehearsal." || true

# Close stale daily-status issues — leave the most recent one open.
gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --json number,createdAt \
  --jq 'sort_by(.createdAt) | reverse | .[1:] | .[].number' \
  | xargs -I{} gh issue close --repo "${GITHUB_REPO}" {} --comment "Superseded." || true

# Close any open CCA PR from the previous run.
gh pr list --repo "${GITHUB_REPO}" --state open --search "head:copilot/fix-products-500" --json number \
  --jq '.[].number' \
  | xargs -I{} gh pr close --repo "${GITHUB_REPO}" {} --delete-branch || true

step "Re-run stage-demo.sh"
"${SCRIPT_DIR}/stage-demo.sh"
