# Sourced by demo-checkpoint-T*.sh — emergency parachute helpers.
#
# Each demo-checkpoint-T<N>.sh script sources this file and then calls
# `cp_open` with one or more URLs. `cp_open` opens each URL in the
# default browser using the platform-appropriate command (macOS `open`,
# Linux `xdg-open`).

set -euo pipefail

CP_REPO_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
[[ -f "${CP_REPO_ROOT}/.env.demo" ]] && {
  # shellcheck source=/dev/null
  source "${CP_REPO_ROOT}/.env.demo"
}
GITHUB_REPO="${GITHUB_REPO:-<owner>/agentic-loop-demo}"

cp_open() {
  for u in "$@"; do
    [[ -z "${u}" || "${u}" == "TBD" ]] && continue
    if command -v open >/dev/null 2>&1; then
      open "${u}"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "${u}"
    else
      echo "Open this URL: ${u}"
    fi
  done
}

cp_banner() {
  local label="$1"; shift
  echo
  echo "=============================================================================="
  echo "  CHECKPOINT  ${label}"
  echo "=============================================================================="
  for u in "$@"; do echo "  → ${u}"; done
  echo
}
