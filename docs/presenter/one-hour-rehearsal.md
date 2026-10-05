# one-hour-rehearsal.md — minimum-viable AM dry-run

> You have 60 minutes in the morning. This file tells you exactly what
> to do, in what order, and what to skip. It assumes Phases A, B, and C
> of `../reference/setup.md` are already complete and `verify-staging.sh` was last
> green Wednesday evening. If those assumptions are not true, **do not
> use this file** — go to `../reference/setup.md`, you need 90+ minutes.

## Pre-conditions you must confirm in the first 5 minutes

```bash
cd ~/code/agentic-loop-demo
source .env.demo

# 1. Tools are still here
gh aw version              # ≥ 0.68.1   (April 10 hotfix — earlier hangs on Copilot CLI v1.0.22)
az --version | head -n1    # ≥ azure-cli 2.60
gh --version  | head -n1   # ≥ gh 2.60

# 2. Auth is still good
az account show --query "{user:user.name, sub:name}" -o tsv
gh auth status

# 3. Wednesday evening's staging is intact
bash scripts/verify-staging.sh    # must print STAGING ✓
```

If any of those four checks fail, the AM rehearsal budget is blown
and you should reset Wednesday's staging via `scripts/restage-demo.sh`
(takes 15–25 min and you don't have it). Skip the dry-run and walk on
stage relying on what was green last night.

## The 50-minute dry-run script

This is the **minimum** that confirms the demo is going to work. Skip
anything not on this list. Every step is tagged with the time you should
spend on it.

### Block 1 — local code + cold open  (10 min)

```bash
# 1. Repo + tests still healthy (the seeded bug must still fire).
( cd src && npm test 2>&1 | tail -10 )
#    Expect: # tests 8  # pass 6  # fail 2     ← the two failing tests
#    are the seeded bugs the Coding Agent fixes on stage.

# 2. /products on production responds 200 (post-Wed-deploy state).
bash scripts/verify-deploy.sh
#    Expect: DEPLOY ✓

# 3. Cold open dry-run.
gh workflow run daily-status.lock.yml --repo "${GITHUB_REPO}"
#    Wait ~30 seconds.
gh run watch --repo "${GITHUB_REPO}" \
  $(gh run list --repo "${GITHUB_REPO}" --workflow daily-status.lock.yml --limit 1 --json databaseId --jq '.[0].databaseId')
#    Expect: green check, AND a new issue with [repo status] prefix in:
gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --limit 3
```

If the cold open fails: open the run logs in the Actions tab. The
single most likely cause is a missing or stale `COPILOT_GITHUB_TOKEN`
secret. Check with `gh secret list --repo "${GITHUB_REPO}"`.

### Block 2 — closed-loop time points 1 → 5  (15 min)

```bash
# 4. Confirm the pre-staged bug + draft PR are still where Wednesday left them.
bash scripts/demo-checkpoint-T2.sh   # opens Issue #2 (assigned to copilot-swe-agent) + the CCA dashboard
bash scripts/demo-checkpoint-T3.sh   # opens the draft PR — should still be Draft state

# 5. Mid-demo stress test: practice the live moments only.
#    DO NOT run scripts/demo-checkpoint-T4.sh in the AM rehearsal (it
#    marks the PR ready for real and CCR fires — you cannot un-fire it
#    without a restage). Just mentally rehearse the click path.

# 6. Confirm the deploy log from Wednesday's run is still in Actions.
bash scripts/demo-checkpoint-T5.sh   # opens the Actions tab on the deploy workflow
```

### Block 3 — failure injection + alert + SRE  (20 min)

This is the only block that *acts* in the AM rehearsal. The
`trigger-failure.sh` guard refuses to fire if production is already
broken, so this is safe to run.

```bash
# 7. Live trigger.
bash scripts/trigger-failure.sh    # ~5 sec; expect "Swap complete" then 500s within ~60 sec
#    (The script polls and prints HTTP codes until it sees 500.)

# 8. Wait for the metric alert to fire (~1–2 min) and SRE Agent to
#    investigate (~3–5 min). Use the time to read your slides.
sleep 90
az monitor metrics alert list --resource-group "${AZURE_RG}" \
  --query "[?contains(name,'5xx')].alertState | [0]" -o tsv
#    Expect: Fired (or Activated)

# 9. SRE Agent visual confirmation.
bash scripts/demo-checkpoint-T7.sh    # opens Wednesday's pre-completed thread
#    If T7 errors with "parachute is not configured" — paste the SRE
#    thread URL into quick-reference.md (see SETUP step C9 / Wednesday
#    checklist).

# 10. Loop close — SRE Agent's GitHub issue.
bash scripts/demo-checkpoint-T8.sh    # opens the issue with sre-agent label
#     If empty: SRE Agent hasn't filed yet — wait another 2 min.
#     If still empty after 5 min total: T8 will be cold on stage. Fall
#     back to Wednesday's pre-staged issue (link in quick-reference.md).

# 11. **CRITICAL** — reset before you walk away.
bash scripts/reset-demo.sh             # restores production = 200 OK
bash scripts/verify-deploy.sh          # confirm DEPLOY ✓ before leaving
```

### Block 4 — final 5 minutes

```bash
# 12. Tabs.
open https://github.com/${GITHUB_REPO}/blob/main/.github/agents/sre-investigator.agent.md   # Tab 0
open https://github.com/${GITHUB_REPO}/blob/main/.github/workflows/daily-status.md          # Tab 1
open https://github.com/${GITHUB_REPO}/actions                                              # Tab 2
open https://github.com/${GITHUB_REPO}/issues?q=is%3Aopen+sort%3Aupdated                    # Tab 3
open https://github.com/copilot/agents                                                      # Tab 4
# Tabs 5–7: Azure Portal Metrics blade, SRE Agent dashboard, fallback recording.
# Open these by hand from quick-reference.md Section 2.

# 13. Print quick-reference.md (page 1 + 2).
# 14. Eat something.
```

## What you are deliberately NOT doing in the 1-hour rehearsal

The full Wednesday-evening flow is in `demo-runbook.md` Section 7. In
60 minutes you cannot run it. Skip:

- `scripts/restage-demo.sh` — 15–25 min because the Coding Agent has to
  re-open the PR. If T2/T3 are broken Thursday morning, you do this
  ANYWAY but accept the demo is now wholly live (Section 9 fallback).
- `scripts/stage-demo.sh` — same reason.
- Capturing the six fallback recordings (Section 6 of DEMO_RUNBOOK).
  This is a Wednesday-afternoon task.
- Dry-running `scripts/failover-to-backup.sh`. Wednesday afternoon
  task. If you didn't do it, regional fail-over is theoretical.
- `bash scripts/verify-end-to-end.sh` — it's 8 minutes of polling and
  duplicates Block 3. Skip in favour of running Block 3 directly.

## If staging is broken Thursday morning

Run, in order:

```bash
bash scripts/reset-demo.sh        # ~30 sec
bash scripts/restage-demo.sh      # 15–25 min — eats your AM budget
bash scripts/verify-staging.sh    # must print STAGING ✓
```

If `restage-demo.sh` doesn't finish in time, fall back to the wholly-
live choreography in `demo-runbook.md` **Section 9** ("FALLBACK ONLY").
You will have ~3 minutes of audience-visible agent waiting. Lean
hard on the honesty disclosure ("the agents take a couple of
minutes — happy to talk through what's happening while we wait")
and Tab 7 (the recording — capture Wednesday).

## Single most important sentence in this file

If `bash scripts/verify-staging.sh` is green at minute 5, you can walk
on stage at minute 60 even if everything else in this dry-run is
incomplete. The verifier *is* the contract.

## Rehearsal-day mistakes that will cost you the demo

1. **Forgetting `bash scripts/reset-demo.sh` after Block 3.** The
   trigger swap stays in production and Thursday's first /products
   call returns 500. The script is on the line above. Run it.
2. **Running `bash scripts/demo-checkpoint-T4.sh`** in the AM
   rehearsal. That marks the PR ready for review and fires CCR. CCR
   comments are durable. Don't.
3. **Editing the daily-status workflow file** in the AM. The workflow
   `.lock.yml` was generated Wednesday — modifying the `.md` without
   re-running `gh aw compile` will cause the lock to be out of sync
   and the cold open to behave unpredictably.
4. **Switching to the rehearsal resource group** for any read in Block 3.
   Tab 6 (SRE Agent dashboard) intentionally points at the *rehearsal*
   group's Wednesday investigation thread; Tab 5 (Metrics) points at
   the *demo* group. They are different. Don't conflate them in the
   morning panic.

## Worked timing

```
05  pre-conditions
10  block 1 — local + cold open
15  block 2 — pre-staged time points
20  block 3 — failure + alert + SRE + reset
05  block 4 — tabs, print, eat
─── 
55 min   buffer = 5 min before any contingency
```

If at any 5-minute checkpoint you are running over, **stop the
rehearsal and trust Wednesday**. The verifier is the contract.

## Sources for the things that bite (researched May 2026)

- **gh-aw v0.68.1 minimum.** Workflows on the Copilot engine hang on
  Copilot CLI v1.0.22; v0.68.1 pins back to v1.0.21.
  https://github.github.com/gh-aw/blog/2026-04-13-weekly-update/
- **Coding Agent assignee CLI form.** The CLI assignee is
  `copilot-swe-agent`; the assignment API rejects GitHub App tokens.
  Use a fine-grained PAT (the repo's `GH_AW_AGENT_TOKEN` secret).
  https://github.github.com/gh-aw/reference/assign-to-copilot/
- **Azure SRE Agent ARM resource type.** `Microsoft.App/agents`,
  API version `2026-01-01`. GA in eastus2, swedencentral,
  australiaeast. https://learn.microsoft.com/en-us/azure/sre-agent/overview
- **App Service slot swap settings behavior.** Settings NOT marked as
  "Deployment slot setting" travel with the slot during a swap. Our
  `INJECT_ERROR` is intentionally non-sticky so the swap moves it
  into production. https://learn.microsoft.com/en-us/azure/app-service/deploy-staging-slots
