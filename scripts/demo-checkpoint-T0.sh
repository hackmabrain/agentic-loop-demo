#!/usr/bin/env bash
# T0 — Clean slate. Show the gh-aw workflow file and the issue list (empty).
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

WORKFLOW_URL="https://github.com/${GITHUB_REPO}/blob/main/.github/workflows/daily-status.md"
ISSUES_URL="https://github.com/${GITHUB_REPO}/issues"

cp_banner "T0  clean slate (workflow file + empty issues)" "${WORKFLOW_URL}" "${ISSUES_URL}"
cp_open  "${WORKFLOW_URL}" "${ISSUES_URL}"
