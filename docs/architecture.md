# Architecture — Agentic Developer Loop demo

This doc explains, in one page, what gets provisioned and how the eight
demo time points (T0–T8) map onto it.

## Component map

```
                ┌─────────────────────────────────────────────────────┐
                │                       GitHub                       │
                │  ┌──────────────┐  ┌─────────────┐  ┌────────────┐ │
                │  │ daily-status │  │ Coding Agent│  │ Code Review│ │
                │  │  (gh-aw)     │  │  PR #3      │  │  comments  │ │
                │  └──────┬───────┘  └──────┬──────┘  └─────┬──────┘ │
                │         │                 │                │       │
                │         ▼                 ▼                ▼       │
                │      Issue #1         draft PR        ready PR     │
                │     (T1 cold open)    (T3)            (T4)         │
                │         │                 │                │       │
                │         └─────────────────┴────────────────┘       │
                │                          │ merge (T5)              │
                └──────────────────────────┼─────────────────────────┘
                                           │ deploy via OIDC
                                           ▼
        ┌──────────────────────────────────────────────────────────────┐
        │                     Azure App Service                        │
        │   ┌──────────────────┐  ┌────────────────┐  ┌─────────────┐  │
        │   │   production     │  │    staging     │  │ historical  │  │
        │   │   INJECT_ERROR=0 │  │ INJECT_ERROR=1 │  │ pre-fix code│  │
        │   └────────┬─────────┘  └────────┬───────┘  └─────────────┘  │
        │            │   ◄───── slot swap (T6 trigger)                 │
        │            ▼                                                  │
        │   500 on /products → Application Insights → Metric Alert     │
        └────────────────────────────┬────────────────────────────────┘
                                     │ Action Group webhook
                                     ▼
                       ┌────────────────────────────┐
                       │     Azure SRE Agent         │
                       │  (preview, eastus2)         │
                       │   - reads telemetry         │
                       │   - consults KB runbook     │
                       │   - investigates            │
                       │   - files GitHub issue (T8) │
                       └─────────────┬──────────────┘
                                     │ MCP file_issue
                                     ▼
                              GitHub Issue (T8)  ← loop closes here
```

## Resources (single Bicep template `infra/main.bicep`)

| Resource                 | Name pattern                       | Purpose                                                    |
|--------------------------|------------------------------------|------------------------------------------------------------|
| Resource group           | `rg-agentic-loop-{rehearsal\|demo}`| Two groups: rehearsal (Wed) and demo (Thu)                 |
| App Service plan         | `plan-aldemo-<suffix>`             | P1v3 Linux, fast cold starts                               |
| App Service              | `app-aldemo-<suffix>`              | Node 20 LTS, system-assigned identity                      |
| Slot: production         | (default)                          | Serves the FIXED code post-T5                              |
| Slot: staging            | `staging`                          | Holds `INJECT_ERROR=1` ready to swap into prod at T6        |
| Slot: historical         | `historical`                       | Holds older builds for cold-open context                    |
| Application Insights     | `appi-aldemo-<suffix>`             | Workspace-based, 100% sampling                             |
| Log Analytics workspace  | `law-aldemo-<suffix>`              | Backing store for App Insights and diagnostic logs         |
| Metric Alert (5xx)       | `alert-5xx-aldemo-<suffix>`        | HTTP 5xx > 5 in 5 min, sev 2                               |
| Action Group             | `ag-aldemo-<suffix>`               | Webhook target for the SRE Agent                           |

Externally provisioned (Portal walkthrough in `reference/setup.md` Phase C, steps C6–C11):

| Component                   | Why it's not in Bicep                                   |
|-----------------------------|---------------------------------------------------------|
| Azure SRE Agent (preview)   | Preview product; ARM coverage is partial. Portal is the safe path. |
| SRE Agent Knowledge Base    | Upload `reference/http-5xx-runbook.md` via Portal.           |
| SRE Agent Incident Plan     | Configured against the 5xx alert.                       |
| SRE Agent GitHub MCP        | Needs a separate PAT scoped to `repo` + `issues:write`. |

## Trust boundaries (slide-callable)

- **Read access:** the `daily-status` agent is `contents: read`,
  `issues: read`, `pull-requests: read`. It cannot write to anything.
- **Write surface:** exactly one — `safe-outputs.create-issue` with
  `max: 1` and `title-prefix: "[repo status] "`. There is no other door.
- **Deploy auth:** OIDC federated credential. No long-lived secrets.
- **Production approval:** GitHub `production` environment requires a
  named reviewer before slot swap. The audience sees a human gate.
- **MCP reach:** the SRE Agent's MCP allowlist is exactly one server:
  the GitHub MCP, and exactly one tool: `file_issue`. Approved.
  Registered. Bounded.

## Time-point map (see `presenter/demo-runbook.md` Section 4 for narration)

| TP | Where the artifact lives                                  |
|----|-----------------------------------------------------------|
| T0 | Branch `t0-clean`, tag `v0-clean`                          |
| T1 | Issue #1 in the repo (`[repo status]` prefix)              |
| T2 | Issue #2 in the repo (assignee: Copilot), tag `v1-bug-filed` |
| T3 | PR #3 (Draft), branch `copilot/fix-products-500`, tag `v2-cca-working` |
| T4 | PR #3 (Ready), with CCR comments, tag `v3-cca-done`         |
| T5 | `main` has the fix; staging deployed; tag `v4-merged`       |
| T6 | Slot swap — INJECT_ERROR=1 in production, tag `v5-failure`  |
| T7 | SRE Agent active investigation thread (Wed-staged)          |
| T8 | GitHub issue filed by SRE Agent, tag `v6-sre-resolved`      |
