# HANDOFF — Agentic Developer Loop demo

**As of:** Wednesday May 6, 2026 (afternoon)
**Demo:** Thursday May 7, 2026 — GitHub Dev Days SF
**Speaker:** Pavan Tallapragada (Microsoft)
**Repo:** https://github.com/hackmabrain/agentic-loop-demo (public)

---

## TL;DR — what's done, what's next

```
[ ✓ ] Local laptop ready (Node 20, az CLI, gh CLI, gh-aw v0.68.1+, Bicep, jq)
[ ✓ ] Demo repo pushed to hackmabrain/agentic-loop-demo (single clean commit)
[ ✓ ] Repo settings configured:
        - secrets:           COPILOT_GITHUB_TOKEN, GH_AW_AGENT_TOKEN
        - production env:    required reviewer = hackmabrain
        - branch protection: main requires 1 review + build-and-test status check
        - Copilot Coding Agent + Code Review: enabled in repo settings
[ ✓ ] verify-github.sh:  GITHUB ✓ (8 checks pre-Azure; bumps to 11 once Azure secrets land)
[ ◔ ] infra/provision.sh --target demo:  STARTED, hit a Bicep permission error and aborted.
        Resource group rg-agentic-loop-demo was created in eastus2 before abort.
[   ] Azure deploy + slot reset
[   ] SRE Agent provisioning (Phase C6–C11, Portal-only, ~35 min)
[   ] verify-azure.sh
[   ] verify-end-to-end.sh
[   ] Capture six fallback recordings (~20 min)
[   ] stage-demo.sh + verify-staging.sh
```

---

## Where to pick up

### Step 0 — fix the Bicep binary permission

The provisioner aborted with:

```
ERROR: [Errno 13] Permission denied: '/Users/pavbond007/.azure/bin/bicep'
```

One-line fix:

```bash
chmod +x ~/.azure/bin/bicep
~/.azure/bin/bicep --version
```

If that doesn't work, reinstall:

```bash
az bicep uninstall 2>/dev/null
az bicep install
xattr -d com.apple.quarantine ~/.azure/bin/bicep 2>/dev/null   # macOS Gatekeeper, just in case
```

### Step 1 — finish provisioning

The script is idempotent. The existing resource group is reused, the deployment proceeds:

```bash
cd /Users/pavbond007/Documents/Microsoft/Workshops/ad_aw_demo/agentic-loop-demo
PYTHONWARNINGS="ignore::SyntaxWarning" \
GITHUB_REPO=hackmabrain/agentic-loop-demo \
  bash infra/provision.sh --target demo
```

**Inputs already pinned:**

```
Subscription: b1229034-5362-455d-ac1c-af0ac10e9d1a
Tenant:       52e86c3f-e16a-4d40-809f-9bb01cb1282d
Region:       eastus2
RG:           rg-agentic-loop-demo
Name suffix:  ptmsft01
GitHub repo:  hackmabrain/agentic-loop-demo
```

When this completes you'll see `DONE — demo provisioning complete.` and `.env.demo` will be written locally with every output (App URL, App Insights connection string, action group name, SRE_API_VERSION, etc.).

### Step 2 — first deploy + reset

```bash
gh workflow run deploy.yml --repo hackmabrain/agentic-loop-demo
gh run watch --repo hackmabrain/agentic-loop-demo \
  $(gh run list --repo hackmabrain/agentic-loop-demo --workflow deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

The deploy will pause on the **production** environment gate. Approve it in the GitHub UI (you're the required reviewer).

After the swap, **reset to demo-ready state** — the slot swap pulls `INJECT_ERROR=1` from staging into production by default, which the demo doesn't want:

```bash
bash scripts/reset-demo.sh
bash scripts/verify-deploy.sh           # expect: DEPLOY ✓
```

### Step 3 — SRE Agent (~35 min, Portal-only)

Open `SETUP.md` and follow Phase C6 → C11 in order. Each step has the screen-by-screen path, every form field, the verification command, and the recovery path if it fails.

> **Heads up on C10 (GitHub MCP connector):** This needs a **third** PAT, not the two already in repo secrets. It's a fine-grained PAT scoped to `Issues: Read & Write` on this one repo. The PAT is provided to the SRE Agent's Portal config — it does NOT need to be a GitHub repo secret.

After C11:

```bash
bash scripts/verify-azure.sh           # expect: AZURE ✓
```

### Step 4 — end-to-end dry run (~10 min)

```bash
bash scripts/verify-end-to-end.sh      # full live cycle: cold open → trigger → alert → SRE Agent → loop close
```

Expect `END-TO-END ✓`. Auto-resets at the end.

### Step 5 — Wednesday evening staging (~40 min)

```bash
# A) Capture six fallback recordings (see docs/fallback/README.md)
# B) Pre-stage the eight time points
bash scripts/stage-demo.sh
bash scripts/verify-staging.sh         # expect: STAGING ✓
```

### Step 6 — Thursday morning at the venue (5 min)

```bash
bash scripts/verify-staging.sh
bash scripts/verify-deploy.sh
# Open the 8 tabs from QUICK_REFERENCE.md Section 2.
# Walk on stage.
```

---

## Critical context to know before continuing

1. **The provisioner is idempotent.** Re-running picks up where it left off. Safe.
2. **The Bicep binary permission issue is purely local** to Pavan's laptop. Won't recur on a different machine.
3. **The `production` environment requires a manual approval** every deploy. That's intentional — it's the visible human gate the audience sees on slide 5.
4. **Slot swap pulls `INJECT_ERROR=1` from staging into production** every deploy because INJECT_ERROR isn't slot-sticky. Always run `scripts/reset-demo.sh` after a fresh deploy to restore demo-ready state.
5. **SRE Agent is preview.** Microsoft.App/agents API version is 2026-01-01. Regions: eastus2, swedencentral, australiaeast. The Portal flow is the canonical setup path; CLI/ARM coverage is partial.
6. **Do NOT run `scripts/demo-checkpoint-T4.sh` in any rehearsal window.** It marks the staged PR ready and fires CCR for real — you cannot un-fire it without `scripts/restage-demo.sh` (15–25 min).
7. **The runbook contract:** if `scripts/verify-staging.sh` is green Thursday morning, the demo will work. The verifier is the contract.

---

## Files to read first if you're picking this up cold

```
1. README.md                — repo overview, what each piece does
2. SETUP.md                 — first-time provisioning (Phase A/B/C, where Pavan is now)
3. DEMO_RUNBOOK.md          — Section 4 (canonical), Section 9 (live-only fallback)
4. QUICK_REFERENCE.md       — print this for stage day
5. ONE_HOUR_REHEARSAL.md    — for a 60-min dry run
6. THIRTY_MIN_PATH.md       — for a 30-min triage
```

---

## Contacts

```
Speaker:                Pavan Tallapragada (Microsoft)
Event-day stage manager <fill in by Wed PM>
GitHub Copilot liaison  <fill in by Wed PM>
Backup laptop person    <fill in by Wed PM>
```

---

## What this handoff does NOT cover

- The slide deck content — that lives in `../decks/` (`ad_aw.pptx` and `ad_aw.pdf`).
- The talk track / speaker notes for the slides themselves — the Q&A answers and stage cues are inlined in `DEMO_RUNBOOK.md` Section 5.
- Anything happening in the parent `ad_aw_demo/` folder — only this `agentic-loop-demo/` repo is the deliverable.
</thinking>