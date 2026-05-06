# THIRTY_MIN_PATH.md — what to do when you have 30 minutes left

> 30 minutes is **not** enough for a full first-time provision (that's
> 90 min — see `SETUP.md`). It is enough to either (a) finish a
> half-done provision, (b) confirm a previously-done provision is
> still good, or (c) salvage a degraded state into a deliverable
> demo. The file you open next depends on which state you're in.
>
> **First**, spend 3 minutes on the diagnostic below. Then go to
> exactly ONE of the three paths.

---

## Step 0 — 3-minute diagnostic (do this first)

Run all four commands. Note which return ✅ vs ❌.

```bash
cd ~/code/agentic-loop-demo
[[ -f .env.demo ]] && echo "✅ .env.demo present" || echo "❌ .env.demo missing"

source .env.demo 2>/dev/null
[[ -n "${APP_URL:-}" ]] && curl -s -o /dev/null -w "$([[ \"$(curl -s -o /dev/null -w '%{http_code}' ${APP_URL}/)\" == \"200\" ]] && echo \"✅\" || echo \"❌\") App reachable at ${APP_URL}\n" $APP_URL/ || echo "❌ App not reachable"

gh repo view "${GITHUB_REPO:-?}" >/dev/null 2>&1 && echo "✅ GitHub repo accessible" || echo "❌ GitHub repo not accessible"

bash scripts/verify-staging.sh >/dev/null 2>&1 && echo "✅ Staging green" || echo "❌ Staging not green"
```

Match your result to one of the three paths:

| Result                                        | Go to                                        |
|-----------------------------------------------|----------------------------------------------|
| All four ✅                                   | **Path A — Verify and walk on**              |
| `.env.demo` ✅, App ✅, repo ✅, Staging ❌    | **Path B — Re-stage in 25 min**              |
| `.env.demo` ❌ or App ❌                      | **Path C — Salvage a partial demo**          |

---

# PATH A — Verify and walk on (20 min, 10 min buffer)

**You're in good shape.** Wednesday's setup survived; the demo will work.
Use the 30 minutes for a confidence pass + tabs.

```bash
# 5 min — fast confidence checks
bash scripts/verify-local.sh           # LOCAL ✓
bash scripts/verify-deploy.sh          # DEPLOY ✓
gh secret list --repo "${GITHUB_REPO}" # confirm: COPILOT_GITHUB_TOKEN, GH_AW_AGENT_TOKEN, AZURE_*

# 10 min — practice the cold open ONCE (don't run T4/T6/T8 in this window)
gh workflow run daily-status.lock.yml --repo "${GITHUB_REPO}"
sleep 30
gh run list --repo "${GITHUB_REPO}" --workflow daily-status.lock.yml --limit 1
gh issue list --repo "${GITHUB_REPO}" --label daily-status --state open --limit 3
# Confirm a new [repo status] issue appeared. That's the cold open verified.

# 5 min — open the 8 tabs in QUICK_REFERENCE.md Section 2
# 5 min — print QUICK_REFERENCE.md, eat, breathe, walk on stage
```

Then on stage, follow `DEMO_RUNBOOK.md` Section 4 (canonical staged
choreography). **Single sentence**: if Step 0 was four ✅, the demo
will work. Don't second-guess.

---

# PATH B — Re-stage in 25 min, 5 min buffer

**Most of the setup is good but the time-point staging has degraded
since last rehearsal** (PR was merged, slot was swapped and not
reset, etc). You need to re-arm.

```bash
# 1 min  — reset the live state
bash scripts/reset-demo.sh

# 15-25 min — re-stage the time points
bash scripts/restage-demo.sh
# This runs: close stale issues, re-fire daily-status, re-file the bug,
# wait for Coding Agent to open the draft PR. The Coding Agent step is
# the longest — usually 5-10 min.

# 2 min — verify
bash scripts/verify-staging.sh         # must print STAGING ✓

# 2 min — open tabs from QUICK_REFERENCE.md, print, walk on
```

If `restage-demo.sh` is still running at minute 25, **stop it
(Ctrl-C)** and proceed to Path C.

---

# PATH C — Salvage a partial demo (the worst case)

**Either you have no `.env.demo`, or the App Service is unreachable.**
You will not have a fully-working live closed loop in 30 minutes. Your
job now is to deliver the *most* of the demo that's possible from
existing artifacts.

What still works without Azure / fresh provision:

1. **Slide 11 (`Agentic Workflows`)** — show the `daily-status.md`
   workflow file from the repo. This is just reading a file — no
   cloud needed.
2. **Cold open against a different repo** — if you have any GitHub
   repo with `gh-aw` set up, run the `daily-status` workflow against
   that. The audience won't know it's a different repo if you don't
   tell them.
3. **The pre-recorded fallback `closed-loop.mov`** — if Wednesday's
   capture exists (`docs/fallback/closed-loop.mov`), play it and
   narrate over it with the honesty disclosure from `DEMO_RUNBOOK.md`
   Section 4.

```bash
# 5 min — confirm what assets are still usable
ls docs/fallback/                                    # do the .mov files exist?
gh repo list --limit 20 | grep -i 'agentic\|aw'      # any other gh-aw repos you can use?

# 10 min — read the deliverable script
# Open DEMO_RUNBOOK.md Section 9 ("FALLBACK ONLY: live-only choreography")
# This is the wholly-live path that does NOT require pre-staging.

# 10 min — emergency tab setup
# Open these 5 tabs only (skip 5, 6, 7 from the normal order):
#   Tab 0: .github/agents/sre-investigator.agent.md  (custom agent file)
#   Tab 1: .github/workflows/daily-status.md         (cold open file)
#   Tab 2: Actions tab (or any gh-aw repo's Actions)
#   Tab 7: docs/fallback/closed-loop.mov             (the recording)

# 5 min — read the honesty disclosure twice (Section 4 of DEMO_RUNBOOK.md)
# Walk on stage. Open with: "Some of what I'll show you was captured
# earlier this week — these agents take a couple of minutes to do
# real work, and I'd rather not have us all watch spinners. The
# triggers and writes happen live; the thinking happened earlier."
# That sentence buys you the entire demo even if the recording is
# 100% of what plays.
```

---

## Direct answer to "which file first, which next"

**If Path A** (everything green): read `ONE_HOUR_REHEARSAL.md` Block 1
+ Block 4 only (skip Blocks 2 + 3). 20 minutes. Then `QUICK_REFERENCE.md`.

**If Path B** (re-stage needed): run `scripts/restage-demo.sh`
immediately. While it runs, read `DEMO_RUNBOOK.md` Section 4 once.
Then `QUICK_REFERENCE.md`.

**If Path C** (partial salvage): read `DEMO_RUNBOOK.md` **Section 9**
("FALLBACK ONLY"). That's the only file that matters in 30 minutes
when you can't get the cloud back. Then `QUICK_REFERENCE.md` for
tab order.

---

## What `SETUP.md` is for

`SETUP.md` is a **90-minute first-time provisioning runbook**. It is
not appropriate for a 30-minute window. If you have not done it
before today and the diagnostic above shows ❌ on `.env.demo`, the
*honest* answer is: you cannot do a full setup in 30 minutes. Path C
is the only realistic option.

## What `ONE_HOUR_REHEARSAL.md` is for

`ONE_HOUR_REHEARSAL.md` assumes setup is fully done and you have 60
minutes to dry-run. Half its blocks (the live trigger + SRE Agent
investigation, ~20 min) don't fit in 30 minutes; that's why this
file exists.

## The single sentence to remember

> **If Step 0's diagnostic is four ✅, you can walk on stage. The
> verifier is the contract.** Everything else is rehearsal hygiene.

---

## Common 30-minute mistakes (do not make these)

1. **Starting `bash infra/provision.sh --target demo` in this window.**
   The Bicep deploy + the SRE Agent Portal walkthrough together take
   45+ minutes. You will run out of time mid-provision and the demo
   will be in an inconsistent state.
2. **Editing `daily-status.md` without re-running `gh aw compile`.**
   The lock file goes out of sync; the cold open behaves
   unpredictably.
3. **Running `bash scripts/demo-checkpoint-T4.sh`** to "test it" in
   the rehearsal window. T4 marks the PR ready for real and CCR
   fires. CCR comments are durable. You then need a full re-stage to
   recover, which doesn't fit in 30 min.
4. **Forgetting `scripts/reset-demo.sh` after `trigger-failure.sh`.**
   Production stays in 500-mode and Thursday's first /products call
   is broken on stage. The `trigger-failure.sh` guard now refuses to
   fire if production is already broken, but the reset is still on
   you.
5. **Trying to capture fallback recordings now.** That's a Wednesday-
   afternoon task; capturing six clips in 30 min while also doing
   anything else is not realistic.
