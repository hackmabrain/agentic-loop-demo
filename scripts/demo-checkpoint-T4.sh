#!/usr/bin/env bash
# T4 — Mark PR Ready for review (this is the live moment, ~10 sec).
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

PR_NUM="$(gh pr list --repo "${GITHUB_REPO}" --state open --search 'head:copilot/fix-products-500' --json number --jq '.[0].number // ""')"
[[ -z "${PR_NUM}" ]] && { echo "ERROR: PR not found."; exit 1; }
echo ">> Marking PR #${PR_NUM} as Ready for review (CCR will fire in ~10 sec)…"
gh pr ready --repo "${GITHUB_REPO}" "${PR_NUM}"
PR_URL="$(gh pr view --repo "${GITHUB_REPO}" "${PR_NUM}" --json url --jq .url)"

cp_banner "T4  PR ready, CCR firing" "${PR_URL}"
cp_open  "${PR_URL}"
