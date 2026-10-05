#!/usr/bin/env bash
# T3 — CCA draft PR (in progress).
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

PR_URL="$(gh pr list --repo "${GITHUB_REPO}" --state open --search 'head:copilot/fix-products-500' --json url --jq '.[0].url // ""')"

cp_banner "T3  Coding Agent draft PR" "${PR_URL:-no PR found}"
cp_open  "${PR_URL}"
