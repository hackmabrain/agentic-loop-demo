#!/usr/bin/env bash
# commit-and-push.sh — commit the local edits (S1 SKU + UI page + tests +
# runbook tab updates) and push to hackmabrain/agentic-loop-demo.
#
# Run from the demo repo root:
#   bash commit-and-push.sh

set -euo pipefail

cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Sanity: are we in the right repo?
[[ -d .git ]] || { echo "ERROR: no .git in $(pwd). Run setup-git.sh first."; exit 1; }
remote="$(git remote get-url origin 2>/dev/null || echo unset)"
[[ "$remote" == *"hackmabrain/agentic-loop-demo"* ]] || {
  echo "ERROR: origin is '$remote' — expected hackmabrain/agentic-loop-demo."
  exit 1
}

echo ">> Repo:    $(pwd)"
echo ">> Remote:  $remote"
echo ">> Author:  $(git config user.name) <$(git config user.email)>"
echo ""

# Show what we're about to commit
echo ">> Changed files since last commit:"
git status --porcelain
echo ""

if [[ -z "$(git status --porcelain)" ]]; then
  echo "Nothing to commit. Working tree clean."
  exit 0
fi

# Stage everything
git add -A

# Single, descriptive follow-up commit
git commit --no-gpg-sign -m "feat(ui): single-page catalog UI + cost-friendly S1 plan

- src/index.html: clean single-page UI (Northwind Outlet) that calls
  /products from the browser. The seeded bug and INJECT_ERROR
  middleware are now visually observable on stage as a clear
  'service unavailable' banner instead of a curl 500.
- src/server.js: GET / serves the HTML; new GET /healthz returns the
  JSON status (used by smoke tests + UI footer build label).
- src/tests/server.test.js: updated to assert HTML at / and JSON at
  /healthz. Test suite remains 7 pass / 2 fail (the failing tests
  are still the seeded bugs the Coding Agent fixes).
- infra/main.bicep + main.parameters.json: drop App Service plan from
  P1v3 (Premium V3) to S1 (Standard) for compatibility with new
  subscriptions / free trial. S1 supports 5 deployment slots which
  covers the 3 the demo needs. ~\$0.10/hour vs P1v3's ~\$0.33/hour.
- DEMO_RUNBOOK.md + QUICK_REFERENCE.md: tab order updated. New Tab 5
  is the live catalog page — the audience's primary visual artefact.

Cost note: end-to-end demo runtime (Wed → Fri teardown) is < \$10 on
S1 + minimal App Insights/Log Analytics, well within the \$200
free-trial credit."

echo ""
echo ">> Pushing to origin..."
git push -u origin main

cat <<EOF

================================================================
Pushed.

  Commit:     $(git log -1 --format='%h %s')
  Author:     $(git log -1 --format='%an <%ae>')
  Files:      $(git diff-tree --no-commit-id --name-only -r HEAD | wc -l | tr -d ' ') changed

Live at: $remote
================================================================
EOF
