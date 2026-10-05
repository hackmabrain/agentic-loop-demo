# The Agentic Developer Loop — Demo

A working demo of three GitHub + Microsoft AI agents collaborating on
real software work, gated by ordinary GitHub primitives — issues and
pull requests — with the same review and approval rules a team already
trusts.

```
        File a bug          GitHub Issue
              │                    ▲
              ▼                    │
   GitHub Copilot          Azure SRE Agent
   Coding Agent ──► PR             ▲
              │                    │
              ▼                    │
   GitHub Copilot          Azure Monitor
   Code Review                     ▲
              │                    │
              ▼                    │
        Human approves      Production fails
              │                    ▲
              ▼                    │
            Deploy ─────────────────
```

Three agents. Different jobs. Same governance. Loop closes on the same
primitive that opened it.

## What you'll see

A live catalog page (Northwind Outlet) initially showing a red error
banner because of a seeded bug. File a bug → an AI fixes it → you
approve the merge → it deploys → the page works → trigger a production
failure → another AI investigates → it files a new GitHub issue →
loop closes.

Every step is a normal GitHub artefact a normal human can audit. The
agents never bypass the controls.

## Try it

You'll need: an Azure subscription with App Service quota, a GitHub
account with Copilot Pro+ or Enterprise, and a Mac or Linux dev
machine with the standard CLIs. Full prereqs in
[`docs/reference/setup.md`](./docs/reference/setup.md).

```bash
git clone https://github.com/hackmabrain/agentic-loop-demo.git
cd agentic-loop-demo

az login
az account set --subscription "<your-sub-id>"
gh auth login

bash quickstart.sh
```

`quickstart.sh` provisions Azure, deploys the seeded-bug "before"
state, and prints the live App URL. ~10 minutes from clone to running
demo. Region fallback (eastus2 → swedencentral → australiaeast)
handles regional quota differences automatically.

After it finishes, the App URL is live with the seeded bug — the same
state your audience sees when the demo opens. Continue with the SRE
Agent Portal walkthrough in
[`docs/reference/setup.md`](./docs/reference/setup.md) (Phase C6–C11,
~35 min in the Azure Portal).

## Cost

Running cost on the recommended SKU (App Service Basic B1 + Application
Insights + Log Analytics + a metric alert) is roughly **$0.10/hour**.
A full demo cycle (provision Wed, demo Thu, teardown Fri) runs around
**$5–$10**. Cleanup is one command — see
[`docs/reference/setup.md`](./docs/reference/setup.md#cleanup).

## What's in this repo

```
agentic-loop-demo/
├── src/                            Express Catalog API + tests + the HTML UI
│   ├── server.js                   Express + INJECT_ERROR middleware
│   ├── routes/products.js          The seeded bug (5 lines)
│   ├── data/catalog.js             10 hardcoded products
│   ├── tests/                      node:test — 2 failing tests are the seeded bug
│   └── index.html                  The audience-facing catalog page
├── infra/                          Bicep IaC (App Service + AI + LAW + alert + action group)
│   └── provision.sh                Idempotent provisioner with region fallback
├── .github/
│   ├── workflows/
│   │   ├── deploy.yml              GitHub Actions deploy via OIDC
│   │   └── daily-status.md         gh-aw cold-open agentic workflow
│   └── agents/
│       └── sre-investigator.agent.md   Custom agent profile
├── scripts/                        Helper scripts (trigger-failure, reset-demo, verify-*)
├── docs/
│   ├── architecture.md             Component map + the eight time points
│   ├── reference/
│   │   ├── setup.md                First-time provisioning runbook (Phase A/B/C)
│   │   ├── http-5xx-runbook.md     SRE Agent Knowledge Base content
│   │   └── demo-issue-template.md  The bug template used during the demo
│   └── presenter/                  Stage-delivery materials (speaker-only)
├── quickstart.sh                   One-shot fresh-laptop setup
└── README.md                       This file
```

## What this is NOT

- **Not a product.** This is a learning artefact for a customer-facing
  demo. The Bicep, scripts, and runbooks are demo-grade.
- **Not for production use.** The Catalog API has an intentional bug.
  The infrastructure is sized for a 7-minute demo, not real load.
- **Not a complete agentic-AI tutorial.** It demonstrates the loop;
  it does not teach how to build agents from scratch. For that, start
  with [GitHub Agentic Workflows docs](https://github.github.com/gh-aw/).

## Local-only smoke test (no Azure required)

```bash
cd src
npm install
npm test       # 7 pass / 2 fail — the failing tests are the seeded bug
npm start      # http://127.0.0.1:8080
open http://127.0.0.1:8080/                                 # the catalog page
curl http://127.0.0.1:8080/products                         # 500 (seeded bug)
curl http://127.0.0.1:8080/products?category=electronics    # 200
```

Use this if you want to read the code without spending Azure credits.

## Built on

- [GitHub Agentic Workflows](https://github.github.com/gh-aw/) (technical preview, Feb 2026)
- [GitHub Copilot Coding Agent](https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent)
- [GitHub Copilot Code Review](https://docs.github.com/copilot/concepts/code-review/about-code-review)
- [Azure SRE Agent](https://learn.microsoft.com/azure/sre-agent/) (preview)
- [Azure App Service](https://learn.microsoft.com/azure/app-service/) on Linux Node 20
- [Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/) for IaC

## License

MIT. Use it, fork it, share it, adapt it. See
[`LICENSE`](./LICENSE).

## For presenters

If you're delivering this as a live talk, the materials in
[`docs/presenter/`](./docs/presenter/) cover stage choreography:
the run-of-show, the printed reference card, and short-window
rehearsal plans. Customers reading this repo can ignore that folder.
