#!/usr/bin/env bash
# T1 — daily-status issue exists. Open the latest [repo status] issue.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

ISSUE_URL="$(gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --json url,createdAt \
  --jq 'sort_by(.createdAt) | reverse | .[0].url' 2>/dev/null || echo "")"
ACTIONS_URL="https://github.com/${GITHUB_REPO}/actions/workflows/daily-status.lock.yml"

cp_banner "T1  daily-status issue (cold-open result)" "${ISSUE_URL:-no issue found}" "${ACTIONS_URL}"
cp_open  "${ISSUE_URL}" "${ACTIONS_URL}"
