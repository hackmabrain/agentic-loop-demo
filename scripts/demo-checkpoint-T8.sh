#!/usr/bin/env bash
# T8 — Loop closed: SRE Agent filed a GitHub issue.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

ISSUE_URL="$(gh issue list --repo "${GITHUB_REPO}" --label sre-agent --state open --json url,createdAt \
  --jq 'sort_by(.createdAt) | reverse | .[0].url' 2>/dev/null || echo "")"

cp_banner "T8  loop closed — SRE-filed issue" "${ISSUE_URL:-no SRE-filed issue yet}"
cp_open  "${ISSUE_URL}"
