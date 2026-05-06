# Agentic Developer Loop — Demo Repository

Demo for **GitHub Dev Days SF — Thursday May 7, 2026.**
Speaker: **Pavan Tallapragada (Microsoft)**.

This repo is the working artefact for the seven-minute live demo at the
end of the talk *The Agentic Developer Loop*. It is intentionally small.
Everything interesting is in the loop, not in the code.

## What this repo contains

```
agentic-loop-demo/
├── .github/
│   ├── workflows/
│   │   ├── deploy.yml            # GH Actions → Azure App Service via OIDC
│   │   ├── daily-status.md       # gh-aw cold-open agentic workflow
│   │   └── daily-status.lock.yml # Compiled by `gh aw compile`
│   └── agents/
│       └── sre-investigator.agent.md   # Custom agent shown on slide 7
├── infra/
│   ├── main.bicep                # Single-file IaC for App Service + slots + AI + LAW + alert
│   ├── main.parameters.json
│   ├── main-backup.bicep         # swedencentral cold standby
│   └── provision.sh              # `--target rehearsal | demo`
├── src/
│   ├── server.js                 # Express + Application Insights + INJECT_ERROR middleware
│   ├── routes/products.js        # ← contains the seeded bug
│   ├── data/catalog.js
│   ├── tests/                    # node:test — one failing test the Coding Agent will fix
│   └── package.json
├── scripts/                      # 15+ helper scripts (trigger, reset, verify, stage, checkpoints)
├── docs/
│   ├── demo-issue-template.md
│   ├── architecture.md
│   └── http-5xx-runbook.md       # Knowledge base content for SRE Agent
├── SETUP.md                      # First-time provisioning runbook (Phase A / B / C)
├── DEMO_RUNBOOK.md               # Rehearsal + demo-day runbook (with time-point staging)
└── QUICK_REFERENCE.md            # Auto-populated reference card for demo day
```

## Read in this order

1. **[SETUP.md](./SETUP.md)** — once. About 90 minutes.
2. **[DEMO_RUNBOOK.md](./DEMO_RUNBOOK.md)** — every rehearsal.
3. **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** — print this. Keep it
   on the second monitor during the talk.

## What the demo proves on stage

- **Cold open (~75 sec):** A `gh-aw` Markdown workflow creates a
  `[repo status]` issue in the repo. Same issue surface a human would
  use. Same governance.
- **Closed loop (~5.5 min):**
  - File a bug → assign to Copilot Coding Agent → CCA opens a draft PR
  - Mark Ready → Copilot Code Review fires → human approves → merge → deploy
  - Trigger a production failure → Azure Monitor alerts → SRE Agent
    investigates → SRE Agent files a new GitHub issue.
  - Loop closes on the same primitive that opened it: a GitHub issue.

## The seeded bug

In `src/routes/products.js`:

```javascript
const category = req.query.category.toLowerCase(); // throws when undefined
```

Five lines. Easy for the Coding Agent to identify. Audience finds the
fix satisfying. There is a unit test in `src/tests/products.test.js`
that **currently fails** — the Coding Agent's PR makes it pass.

## The production failure

The staging slot has `INJECT_ERROR=1`. `scripts/trigger-failure.sh`
performs a slot swap that brings `INJECT_ERROR=1` into production. The
middleware in `src/server.js` returns HTTP 500 on `/products` and emits
the structured trace the SRE Agent's knowledge base keys off of.

## Local quick-start

```bash
cd src
npm install
npm test       # 7 pass, 1 fail (the seeded bug)
npm start      # http://127.0.0.1:8080
curl http://127.0.0.1:8080/products                       # 500 (bug)
curl http://127.0.0.1:8080/products?category=electronics  # 200
```

## License

MIT. Demo code only — not for production use as-is.
