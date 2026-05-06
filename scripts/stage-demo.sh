#!/usr/bin/env bash
# stage-demo.sh — pre-stages all eight time points for Thursday's demo.
#
# Run this Wednesday evening. Takes ~15–25 minutes (mostly waiting on
# the Coding Agent to open the draft PR). On exit, the demo group has:
#   - tag v0-clean  (T0)
#   - Issue #1 [repo status] (T1, from gh-aw)
#   - Issue #2 the bug, assigned to Copilot (T2)
#   - branch copilot/fix-products-500 (T3)
#   - draft PR #3 from Copilot (T3)
#   - tags v1..v4 carved at the right historical points
#   - production slot serving FIXED code (T5)
#   - staging slot with INJECT_ERROR=1 (ready to swap into prod for T6)
# And the rehearsal group has:
#   - a complete SRE Agent investigation from a real failure trigger (T7)
#   - a real SRE-Agent-filed GitHub issue (T8)
#
# After this completes, run scripts/verify-staging.sh.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

DEMO_ENV="${REPO_ROOT}/.env.demo"
REH_ENV="${REPO_ROOT}/.env.rehearsal"
[[ -f "${DEMO_ENV}" ]] || { echo "ERROR: .env.demo missing — run infra/provision.sh --target demo first."; exit 1; }
[[ -f "${REH_ENV}"  ]] || { echo "ERROR: .env.rehearsal missing — run infra/provision.sh --target rehearsal first."; exit 1; }

# shellcheck source=/dev/null
source "${DEMO_ENV}"
GITHUB_REPO="${GITHUB_REPO:?must be set in .env.demo}"

step() { echo; echo "── $1 ──"; }

# --- T0: tag v0-clean on main if absent ------------------------------------
step "T0: tag v0-clean"
git -C "${REPO_ROOT}" rev-parse v0-clean >/dev/null 2>&1 || {
  git -C "${REPO_ROOT}" tag -f v0-clean main
  git -C "${REPO_ROOT}" push origin v0-clean -f
}

# --- T1: gh-aw daily-status creates Issue #1 -------------------------------
step "T1: fire daily-status workflow → Issue #1"
gh workflow run daily-status.lock.yml --repo "${GITHUB_REPO}" >/dev/null

deadline=$((SECONDS + 120))
issue1_num=""
while (( SECONDS < deadline )); do
  issue1_num="$(gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --json number,title --jq '.[0].number // ""')"
  [[ -n "${issue1_num}" ]] && break
  sleep 5
done
[[ -n "${issue1_num}" ]] || { echo "ERROR: daily-status did not produce an issue."; exit 1; }
echo "Issue #${issue1_num} created."

# --- T2: file Issue #2 (the bug) and assign Copilot ------------------------
step "T2: file Issue #2 (bug report)"
# The issue body is a literal heredoc here so it cannot drift if anyone
# edits docs/demo-issue-template.md. The .md file remains the human-
# readable canonical version; we accept that the two may diverge.
ISSUE_BODY="$(cat <<EOF
The Catalog API is returning HTTP 500 on GET /products with no query string.

Reproduction:

  curl -i ${APP_URL}/products
  HTTP/1.1 500 Internal Server Error

  curl -i ${APP_URL}/products?category=electronics
  HTTP/1.1 200 OK

Expected:
  GET /products with no query string should return the full catalog with
  HTTP 200. The bug appears to be a missing nil-check on req.query.category.

Acceptance criteria:
  - GET /products → 200, full list
  - GET /products?category=electronics → 200, electronics only
  - GET /products?category=does-not-exist → 400 (input validation)
  - At least one regression test that fails today and passes after the fix.

Assignee: @copilot (please pick this up)
Priority: high — visible from /products on production
EOF
)"

# Create the issue first; assign to the Copilot Coding Agent in a second
# call. Copilot's CLI assignee is the bot account `copilot-swe-agent` —
# `Copilot` (the friendly name) is what the GitHub web UI shows but is
# not the username the API expects. Source:
#   https://github.github.com/gh-aw/reference/assign-to-copilot/
# This call requires a fine-grained PAT with Issues:Write — provide it via
# `gh auth login` or via the GH_AW_AGENT_TOKEN magic secret. GitHub App
# installation tokens are rejected by the assignment API.
issue2_num="$(gh issue create \
  --repo "${GITHUB_REPO}" \
  --title "Catalog API returning 500s on /products" \
  --body "${ISSUE_BODY}" \
  --label bug,high-priority \
  | sed 's:.*/::')"

if gh issue edit "${issue2_num}" --repo "${GITHUB_REPO}" --add-assignee copilot-swe-agent 2>/dev/null; then
  echo "Issue #${issue2_num} filed and assigned to Copilot Coding Agent."
elif gh issue edit "${issue2_num}" --repo "${GITHUB_REPO}" --add-assignee copilot 2>/dev/null; then
  echo "Issue #${issue2_num} filed and assigned to Copilot (via 'copilot' alias)."
else
  cat <<EOF
WARN: Issue #${issue2_num} was created but Copilot Coding Agent
      assignment via gh CLI failed. Manual fallback (works every time):

      1. Open: https://github.com/${GITHUB_REPO}/issues/${issue2_num}
      2. Right sidebar → Assignees → search "Copilot" → pick the
         "Copilot" bot result.
      3. Save.

      The Coding Agent will react with 👀 and start a session.
EOF
fi
git -C "${REPO_ROOT}" tag -f v1-bug-filed main
git -C "${REPO_ROOT}" push origin v1-bug-filed -f

# --- T3: wait for Coding Agent to open the draft PR ------------------------
step "T3: wait for Coding Agent draft PR"
deadline=$((SECONDS + 600))   # up to 10 min
pr_num=""
while (( SECONDS < deadline )); do
  pr_num="$(gh pr list --repo "${GITHUB_REPO}" --state open --search "head:copilot/fix-products-500" --json number --jq '.[0].number // ""')"
  [[ -n "${pr_num}" ]] && break
  echo "   waiting on Coding Agent (elapsed ~$((SECONDS / 60)) min)…"
  sleep 30
done
[[ -n "${pr_num}" ]] || { echo "ERROR: Coding Agent did not open a PR within 10 minutes. Re-check assignee on Issue #${issue2_num}."; exit 1; }
echo "Draft PR #${pr_num} opened."

# Force the PR into Draft state if it auto-promoted to Ready.
gh pr ready --repo "${GITHUB_REPO}" "${pr_num}" --undo >/dev/null 2>&1 || true
git -C "${REPO_ROOT}" tag -f v2-cca-working main
git -C "${REPO_ROOT}" push origin v2-cca-working -f

# --- T7 + T8: pre-fire the rehearsal-group failure for SRE Agent -----------
step "T7+T8: pre-fire rehearsal failure for SRE Agent"
"${SCRIPT_DIR}/trigger-failure.sh" --target rehearsal || {
  echo "WARN: rehearsal trigger failed; skipping SRE Agent pre-stage."
}
echo "Wait ~5–10 min for SRE Agent to investigate and file an issue on the rehearsal group."
echo "stage-demo.sh continues in 8 minutes — go drink water."
sleep 480

# --- Capture URLs for QUICK_REFERENCE.md -----------------------------------
step "Updating QUICK_REFERENCE.md with TIME-POINT URLs"
sre_thread_url="(open Azure Portal → SRE Agent → Investigations and copy the most recent thread URL)"
sre_issue_url="$(gh issue list --repo "${GITHUB_REPO}" --label sre-agent --state open --json url --jq '.[0].url // ""')"

python3 - "${REPO_ROOT}/QUICK_REFERENCE.md" <<PYEOF
import re, sys, pathlib
qr = pathlib.Path(sys.argv[1])
text = qr.read_text()
block = f"""<!-- AUTO:TIMEPOINTS:START -->
T0  Clean repo (raw view)         https://github.com/${GITHUB_REPO}/tree/v0-clean
T1  Daily-status issue            https://github.com/${GITHUB_REPO}/issues/${issue1_num}
T2  Bug filed, assigned to Copilot https://github.com/${GITHUB_REPO}/issues/${issue2_num}
T3  CCA draft PR (in progress)    https://github.com/${GITHUB_REPO}/pull/${pr_num}
T4  PR ready, CCR comments        https://github.com/${GITHUB_REPO}/pull/${pr_num}  (mark Ready on stage)
T5  Merged + deployed             https://github.com/${GITHUB_REPO}/actions  (Wed's run)
T6  Slot swap trigger             $ bash scripts/trigger-failure.sh
T7  SRE Agent investigation       {sre_thread_url}
T8  SRE Agent filed issue         {sre_issue_url or '(populated after Wed run completes)'}
<!-- AUTO:TIMEPOINTS:END -->"""
text = re.sub(r"<!-- AUTO:TIMEPOINTS:START -->.*?<!-- AUTO:TIMEPOINTS:END -->", block, text, flags=re.DOTALL)
qr.write_text(text)
print("QUICK_REFERENCE.md updated.")
PYEOF

cat <<EOF

=============================================================================
STAGING COMPLETE.
  Issue #1 (daily-status):  ${issue1_num}
  Issue #2 (bug):           ${issue2_num}
  PR #3 (Copilot draft):    ${pr_num}
  Tags pushed:              v0-clean, v1-bug-filed, v2-cca-working

Next: bash scripts/verify-staging.sh   (confirms all eight time points)
=============================================================================
EOF
