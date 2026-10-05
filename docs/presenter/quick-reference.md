# QUICK_REFERENCE — print this. Keep it on the second monitor.

> Two pages, max. Auto-populated values live in the AUTO blocks below
> and are filled in by `infra/provision.sh`. Never edit them by hand.

---

## SECTION 1 — Variables

<!-- AUTO:VARS:demo:START -->
AZURE_SUBSCRIPTION_ID = (run `bash infra/provision.sh --target demo`)
AZURE_TENANT_ID       =
AZURE_RG_DEMO         = rg-agentic-loop-demo
APP_URL               =
APP_NAME              =
APPI_NAME             =
LAW_NAME              =
ACTION_GROUP_NAME     =
<!-- AUTO:VARS:demo:END -->

<!-- AUTO:VARS:rehearsal:START -->
AZURE_RG_REHEARSAL    = rg-agentic-loop-rehearsal
<!-- AUTO:VARS:rehearsal:END -->

GITHUB_REPO     = (set in .env.demo)
SRE_AGENT_NAME  = sre-aldemo (you choose this in SETUP step C6)

---

## SECTION 2 — Tab order (set up before walking on stage)

0. `…/blob/main/.github/agents/sre-investigator.agent.md`  (custom agent file — open if asked about Slide 7 or in Q&A)
1. `…/blob/main/.github/workflows/daily-status.md`  (raw view of cold-open workflow)
2. `…/actions`  (Actions tab)
3. `…/issues?q=is%3Aopen+sort%3Aupdated`  (Issues, newest first)
4. `https://github.com/copilot/agents`  (Coding Agent dashboard)
5. **`${APP_URL}/`  ← THE LIVE CATALOG PAGE — audience sees every demo state here**
6. Azure Portal → App Service → Metrics blade focused on the last 5 min
7. Azure Portal → SRE Agent dashboard
8. `file:///<path>/docs/fallback/closed-loop.mov`  (the recovery recording — always last tab)

---

## SECTION 3 — Demo timing (visible at a glance)

```
00:00  Cold open begins
01:15  Closed loop begins
02:30  Mark PR ready  → CCR fires
03:30  Merge PR       → deploy
04:30  Trigger failure (live)
05:30  SRE Agent dashboard
06:30  Loop closes — show SRE-filed issue
07:00  Click forward to Slide 16
```

---

## SECTION 4 — One-line failure recovery

```
gh-aw hangs       → "Stage Wi-Fi has opinions"           → Tab 7 GIF
CCA doesn't pick up → check assignee = Copilot           → Tab 7 GIF
Deploy hangs      → switch to pre-recorded deploy GIF    → Tab 7
SRE Agent silent  → switch to Wednesday's investigation  → Tab 6
Catastrophic      → bash scripts/failover-to-backup.sh   (5 min)
```

---

## SECTION 5 — One-line resets

```
Between rehearsals    bash scripts/reset-demo.sh
Re-stage time points  bash scripts/restage-demo.sh
Wed-evening pre-stage bash scripts/stage-demo.sh && bash scripts/verify-staging.sh
Post-demo cleanup     az group delete --name $AZURE_RG_DEMO --yes
```

---

## SECTION 6 — Key sentences (memorised)

```
Slide 5:   "Same review. Same approvals. Same logs."
Slide 7:   "Lowest scope wins."
Slide 8:   "A prompt impresses once. Primitives are the part you can trust tomorrow."
Slide 9:   "Not a free-for-all. A guest list."
Slide 12:  "See wide. Write narrow."
Slide 13:  "Adopting GitHub's Agentic Workflows lowered the barrier for
            experimentation."  — Chris Aniszczyk, CTO, CNCF
            (github.blog, Feb 2026 — verifiable, attributable)
Demo:      "Same primitive. Same governed create-issue path."
Slide 16:  "The repo keeps working between human moments."
Slide 17:  (silence — let the question land)
```

> Numerics policy: do not put a number on this card unless it is from a
> source you can name on stage. The CNCF / Carvana / Home Assistant
> quotes from the GitHub Feb 2026 blog post are pre-cleared.

---

## SECTION 7 — TIME-POINT URLS

<!-- AUTO:TIMEPOINTS:START -->
T0  Clean repo (raw view)         (filled by stage-demo.sh)
T1  Daily-status issue            (filled by stage-demo.sh)
T2  Bug filed, assigned to Copilot (filled by stage-demo.sh)
T3  CCA draft PR (in progress)    (filled by stage-demo.sh)
T4  PR ready, CCR comments        (filled by stage-demo.sh)
T5  Merged + deployed             (filled by stage-demo.sh)
T6  Slot swap trigger             $ bash scripts/trigger-failure.sh
T7  SRE Agent investigation       (filled by stage-demo.sh — Wed)
T8  SRE Agent filed issue         (filled by stage-demo.sh — Wed)
<!-- AUTO:TIMEPOINTS:END -->

---

## SECTION 8 — Day-of contacts

```
Event-day stage manager   <name / phone>
Microsoft on-call SE      <name / phone>
GitHub Copilot product liaison <name / phone>
Backup laptop person      <name / phone>
```

(Pavan: fill these in by Wednesday afternoon. Print this page.)
