#!/usr/bin/env bash
# T7 — SRE Agent investigation in progress (use Wednesday's pre-completed thread).
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/_checkpoint-common.sh"

# Pull the SRE Agent dashboard URL from docs/presenter/quick-reference.md if available.
SRE_THREAD_URL="$(grep -E '^T7' "${CP_REPO_ROOT}/docs/presenter/quick-reference.md" 2>/dev/null \
  | sed -E 's/^T7[[:space:]]+[^ ]+[[:space:]]+//' \
  | tr -d '[:space:]' || true)"

# Fail loud at rehearsal if the URL was never populated. The placeholder
# pattern matches what stage-demo.sh writes when it cannot auto-fetch the
# thread URL from the preview API. Better to fail at rehearsal than to
# open a broken/empty tab on stage.
if [[ -z "${SRE_THREAD_URL}" \
   || "${SRE_THREAD_URL}" == "(filledbystage-demo.sh—Wed)" \
   || "${SRE_THREAD_URL}" == *"openAzurePortal"* ]]; then
  cat >&2 <<EOF
ERROR: T7 parachute is not configured.

The SRE Agent thread URL has not been populated in docs/presenter/quick-reference.md.
This is normally written by stage-demo.sh on Wednesday. If the preview
API did not expose the thread URL, you must paste it manually:

  1. Open Azure Portal → SRE Agent → Investigations.
  2. Copy the URL of the most recent completed thread.
  3. Edit docs/presenter/quick-reference.md and replace the T7 line with that URL
     (between the AUTO:TIMEPOINTS markers).
  4. Re-run this script.
EOF
  exit 1
fi

cp_banner "T7  SRE Agent investigation" "${SRE_THREAD_URL}"
cp_open  "${SRE_THREAD_URL}"
