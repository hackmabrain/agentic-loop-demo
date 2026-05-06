# DEMO_RUNBOOK.md — rehearsal & demo-day playbook

> Read this once Wednesday morning. Skim it before every rehearsal.
> Re-skim it Thursday morning at the venue.
>
> **The canonical demo choreography is Section 4** (time-point staged).
> Section 9 ("FALLBACK ONLY") is the wholly-live version, kept only for
> the case where staging breaks and cannot be repaired before the talk.

---

## Section 1 — The seven-minute demo at a glance

```
0:00 ─ 1:15  Cold open                  daily-status (gh-aw)
1:15 ─ 6:30  Closed loop                 bug → CCA → CCR → merge → deploy → fail → SRE Agent → issue
6:30 ─ 7:00  Land the close              "Same primitive. Same governed create-issue path."
```

The cold open is mostly live (~30 sec of Actions wait, fully narrated).
The closed loop is mostly pre-staged with four live moments: filing
the bug, marking the PR ready, merging, and triggering the slot swap.
Total live waiting time across 7 minutes: ~60 seconds.

---

## Section 2 — Browser tab order

| # | URL                                                                  | Purpose                                                                 |
|---|----------------------------------------------------------------------|-------------------------------------------------------------------------|
| 0 | `…/blob/main/.github/agents/sre-investigator.agent.md`               | Custom agent — open if asked about Slide 7 / Q&A                       |
| 1 | `…/blob/main/.github/workflows/daily-status.md`                      | Show the agentic workflow file                                          |
| 2 | `…/actions`                                                          | Run + watch the gh-aw run                                               |
| 3 | `…/issues?q=is%3Aopen+sort%3Aupdated`                                | Issues, newest first                                                    |
| 4 | `https://github.com/copilot/agents`                                  | Coding Agent dashboard                                                  |
| 5 | **`https://<APP_URL>/`** (the live catalog page)                     | **The visual story.** Audience sees the page break + heal in real time. |
| 6 | Azure Portal → App Service → **Metrics** (5xx, last 5 min)           | Show alert firing                                                       |
| 7 | Azure Portal → SRE Agent → Investigations dashboard                  | Show investigation thread                                               |
| 8 | `file:///<repo>/docs/fallback/closed-loop.mov`                       | The all-in-one fallback recording                                       |

Open tabs in this order, then alt-tab numerically. Tab 0 is the Q&A
parachute — it should never come up unless someone asks. **Tab 5 is
new and important** — it's the live catalog page (Northwind Outlet).
Every demo state is visible there:

- Pre-fix:           red banner, "we're having trouble loading the catalog · HTTP 500"
- Post-CCA-fix:      product grid renders, "live · 10 items"
- Post slot swap:    red banner again (different cause, same symptom)
- After SRE Agent:   product grid back, audience sees the loop close visually

---

## Section 3 — The cold-open script (75 sec)

**Setup:** Tab 1 (workflow file) front-most.

**Speaker beat:**

> *"Let me show you what an agentic workflow looks like. This file
> lives in `.github/workflows`. It's Markdown. Triggers, permissions,
> tools, and the one declared write are right at the top. Below that
> — plain English instructions for the agent."*

Switch to Tab 2 (Actions).

> *"Run workflow. It runs in normal Actions infrastructure with normal
> Actions permissions. While it's running, look at the safe-outputs
> declaration. One write — create an issue, prefixed `[repo status]`,
> max one. That is the entire surface."*

Wait ~30 sec. Switch to Tab 3 (Issues).

> *"And there it is. A normal GitHub issue. Filed by an agent. Through
> exactly the same primitive a human would have used."*

**Transition into closed loop (one sentence):**

> *"And that was the simplest version — one issue, created. Now I'll
> show you the full loop, where one bug becomes a fix, gets reviewed,
> deploys, fails in production, and gets re-investigated. All inside
> the same governance you just saw."*

---

## Section 4 — The closed-loop script (5.5 min) — **CANONICAL, time-point staged**

> Section 9 is kept as a fallback ONLY for the case where staging is
> broken and cannot be re-staged before the talk. Use Section 4.

### Why we stage

Audiences forgive almost anything except watching an AI think.
Spinners over 5 sec leak the room's attention. We pre-create the
artifacts that take time to produce — the PR, the deploy, the SRE
Agent investigation — Wednesday evening, then click between them on
stage like flipping pages in a book.

Total live waiting time: ~60 sec across 7 minutes.

### Honesty disclosure (read once before the demo, slide 15)

> *"One note before we start. Some of what you're about to see was run
> a few minutes ago — Copilot Coding Agent and the SRE Agent both take
> a couple of minutes to do real work, and I'd rather not have us all
> watch spinners. Everything is real artifacts from real runs. The
> triggers and writes happen live. The thinking happened earlier."*

That sentence buys you the entire demo. Engineering leaders especially
appreciate the honesty — they all do this themselves.

### Beat sheet

| Beat            | Time     | Live? | What happens                                                   |
|-----------------|----------|-------|----------------------------------------------------------------|
| File bug live   | 1:15–1:30 | live  | Paste from `docs/demo-issue-template.md`, assignee=Copilot     |
| Show Wed's PR   | 1:30–2:30 | clicks| Pre-staged PR #3 (Draft), walk the diff                        |
| Mark Ready      | 2:30–2:40 | live  | CCR fires within ~10 sec                                       |
| Walk CCR        | 2:40–3:10 | clicks| Already-rendered CCR comments                                  |
| Merge           | 3:10–3:20 | live  | Click merge                                                    |
| Show deploy log | 3:20–4:00 | clicks| Wed's deploy run                                               |
| Trigger fail    | 4:00–4:10 | live  | `bash scripts/trigger-failure.sh`                              |
| Watch metrics   | 4:10–5:00 | mixed | Real new 5xx data appears within ~30 sec (Wed's data also visible) |
| SRE thread      | 5:00–6:00 | clicks| Wed's pre-completed SRE Agent investigation                    |
| Loop closes     | 6:00–6:30 | clicks| Wed's SRE-filed issue                                          |
| Land it         | 6:30–7:00 | speak | "Same primitive. Same governed create-issue path."             |

### Recovery if any single beat breaks mid-demo

For any beat: jump to the matching `bash scripts/demo-checkpoint-T<N>.sh`
script. It opens the right tabs in under 2 seconds. If the parachute
itself fails, jump to Tab 7 (the all-in-one fallback recording) and
narrate over it.

---

## Section 5 — Failure modes and recovery + Q&A answers

### Failure modes

| Symptom                            | One-line recovery                                          |
|------------------------------------|------------------------------------------------------------|
| `gh-aw` run hangs > 60 sec         | "Stage Wi-Fi has opinions" → Tab 7 fallback recording      |
| CCA does not pick up assignment    | Re-check assignee = `Copilot` → if still nothing, Tab 7    |
| Deploy hangs                       | Skip to Tab 7 deploy section                               |
| Slot swap takes > 90 sec for 500s  | Narrate while waiting; if > 2 min, jump to Tab 6           |
| SRE Agent silent                   | Switch to Wednesday's Tab 6 thread (still real)            |
| Catastrophic                       | `bash scripts/failover-to-backup.sh` (5 min)               |

### Q&A — prepared answers (memorise these)

**Cost / billing.** *"Each run consumes coding-agent billing — for
example, with Copilot on default settings, each agentic workflow run
typically incurs two premium requests: one for the agent work, one for
the safe-outputs guardrail check. Engine selection is configurable,
which is one of the levers customers use to manage cost."*

**Engine portability.** *"GitHub Copilot is the engine I'm showing
today, and it's the default for `gh-aw`. The workflow is engine-
neutral by design — the natural-language Markdown stays the same
regardless of which coding agent runs it. That portability is part
of the design, not the headline."*

**Data and tenancy.** *"Workflows run in GitHub Actions. They inherit
the GitHub Actions sandboxing model, scoped permissions, and auditable
execution. Deeper boundary questions inside GitHub Enterprise — let's
take that one offline so I can pull in the right specialist."*

**'Is anything ever auto-merged?'** *"No. Pull requests from agentic
workflows are never merged automatically. Humans must always review and
approve. That's a deliberate design choice — which I imagine your
security team will receive with relief."*

**Rollout sequence.** *"Start with low-risk outputs — comments, drafts,
reports. Then enable PR creation. Then expand to the more opinionated
workflows. Treat the workflow Markdown itself as code — review changes,
keep them small, evolve intentionally."*

**'Where do I start Monday?'** *"Pick one repository where the backlog
is hot and the human cost of triage is real. Add a single agentic
workflow for triage. Watch it for a week. Then add the second one. The
pattern stacks."*

**'Show me your custom agent.'** Open Tab 0 — the
`.github/agents/sre-investigator.agent.md` file. Walk through the YAML
frontmatter (name, description, tools allowlist) and the markdown body.
Land the line: *"This agent has three tools, one job, no ability to
merge. That's the whole template."*

---

## Section 6 — Pre-recorded fallback recordings (Wednesday afternoon)

Capture six clips on Wednesday afternoon (~20 min total). Use
QuickTime Player → New Screen Recording, or Loom. Save to
`docs/fallback/`.

| Clip                              | Length  | Show                                                |
|-----------------------------------|---------|-----------------------------------------------------|
| `gh-aw-run.mov`                   | 30 sec  | Running the daily-status workflow + the issue       |
| `cca-pr-ready.mov`                | 60 sec  | Marking the PR ready and CCR's comments arriving    |
| `merge-deploy.mov`                | 75 sec  | Merge → deploy run → manual approval → slot swap    |
| `trigger-failure.mov`             | 30 sec  | `trigger-failure.sh` + 500s appearing on /products  |
| `sre-agent-investigation.mov`     | 90 sec  | SRE Agent investigation thread + filed issue        |
| **`closed-loop.mov`**             | ~5 min  | Single concatenation of #1–#5 — the catastrophic-fallback master |

After capture:

```bash
ls -la docs/fallback/
# Should list all six .mov files. Tab 7 references closed-loop.mov.
```

If a recording has audio noise from your environment, mute the clip in
QuickTime (Edit → Remove Audio). The recovery flow narrates over the
recording on stage.

---

## Section 7 — Day-of checklist

### Wednesday afternoon

```
[ ] Run: bash scripts/verify-azure.sh             # AZURE ✓
[ ] Capture six fallback recordings → docs/fallback/  (Section 6)
[ ] Dry-run failover once with a throwaway suffix:
      NAME_SUFFIX=throwaway01 bash scripts/failover-to-backup.sh
      Confirm 200 on backup URL.
      az group delete --name rg-agentic-loop-demo-backup --yes --no-wait
[ ] Run: bash scripts/stage-demo.sh               # ~15–25 min, walk away
[ ] Run: bash scripts/verify-staging.sh           # STAGING ✓
[ ] Open QUICK_REFERENCE.md → confirm AUTO blocks are populated
[ ] Manually paste the SRE Agent thread URL into QUICK_REFERENCE.md
    (the preview API may not expose it; copy from Portal → SRE Agent
     → Investigations → most recent thread)
```

### Thursday morning, at the venue

```
[ ] Run: bash scripts/verify-staging.sh           # STAGING ✓
[ ] Run: bash scripts/verify-deploy.sh            # DEPLOY ✓
[ ] Open all 8 tabs in Section 2 order (Tab 0 too)
[ ] Set browser zoom to 125%
[ ] Set terminal font to 18pt
[ ] Plug in HDMI; mirror displays
[ ] Test microphone
[ ] Print QUICK_REFERENCE.md (page 1 + 2)
[ ] Eat something
```

---

## Section 8 — Reset procedure between rehearsals

```
bash scripts/reset-demo.sh        # restores production = 200 OK
bash scripts/restage-demo.sh      # re-files the demo bug + re-stages PR #3 in Draft
gh issue list --state open        # confirm: only Issue #1 ([repo status]) and Issue #2 (the bug)
```

`reset-demo.sh` is fast (~30 sec). `restage-demo.sh` takes ~5–10 min
because the Coding Agent needs time to re-open the PR. Plan rehearsals
at least 15 minutes apart.

`restage-demo.sh` only closes the demo's specific bug issue (matched by
exact title); other issues in the repo are left alone.

---

## Section 9 — FALLBACK ONLY: live-only choreography

> Use this **only** if `verify-staging.sh` fails on Thursday morning AND
> there is no time to re-stage. The 7 minutes will include ~3 minutes of
> live agent waiting — a markedly worse audience experience.

If running fully live (no staging):

1. File Issue #2 → assign Copilot. **Wait 30–90 sec.**
2. CCA opens draft PR → walk through the diff while it's still rendering.
3. Mark **Ready for review**. **Wait ~10 sec** for CCR.
4. Read CCR comments aloud, then merge.
5. Deploy runs (~2 min). Narrate the staging slot smoke test, the
   manual approval, the production swap.
6. Run `bash scripts/trigger-failure.sh`. **Wait ~60 sec** for 500s.
7. Switch to App Service Metrics → wait for the spike.
8. Switch to SRE Agent dashboard → wait for the investigation.
9. Switch to Issues → SRE Agent's filed issue closes the loop.

If you go this route, lean harder on the honesty disclosure ("the agents
take a couple of minutes — happy to talk through what's happening while
we wait"), and have Tab 7 ready to fall back to.
