#!/usr/bin/env bash
# T2 — Bug filed, assigned to Copilot.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

BUG_URL="$(gh issue list --repo "${GITHUB_REPO}" --label bug --state open --search 'assignee:Copilot' --json url --jq '.[0].url // ""')"
CCA_DASH="https://github.com/copilot/agents"

cp_banner "T2  bug filed, assignee=Copilot" "${BUG_URL:-no bug found}" "${CCA_DASH}"
cp_open  "${BUG_URL}" "${CCA_DASH}"
