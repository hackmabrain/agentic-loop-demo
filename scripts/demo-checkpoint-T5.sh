#!/usr/bin/env bash
# T5 — Merged + deployed. Open the most recent successful deploy run.
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

ACTIONS_URL="https://github.com/${GITHUB_REPO}/actions/workflows/deploy.yml"

cp_banner "T5  merged + deployed" "${ACTIONS_URL}"
cp_open  "${ACTIONS_URL}"
