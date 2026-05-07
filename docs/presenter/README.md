# For presenters — stage delivery materials

This folder is for someone delivering this demo as a live talk or
recorded session. **If you're a customer reading this repo to learn
the loop, you can ignore everything in this folder.** The runbooks
here describe stage choreography, not how the demo works.

## Files

| File | Purpose |
|---|---|
| [`demo-runbook.md`](./demo-runbook.md) | Rehearsal + demo-day playbook. Section 4 is the canonical staged choreography; Section 9 is the wholly-live fallback if pre-staging breaks. |
| [`quick-reference.md`](./quick-reference.md) | Two-page reference card to print and keep on the second monitor during the talk. Auto-populated by `infra/provision.sh`. |
| [`one-hour-rehearsal.md`](./one-hour-rehearsal.md) | Minute-by-minute plan for a 60-minute pre-talk dry run. |
| [`thirty-min-path.md`](./thirty-min-path.md) | Triage decision tree when prep time is 30 minutes or less. Has three branches based on the current state of the deployment. |

## What's NOT in here

- **Provisioning** — that's [`docs/reference/setup.md`](../reference/setup.md).
- **Architecture** — that's [`docs/architecture.md`](../architecture.md).
- **The repo's main README** — that's [`README.md`](../../README.md) at the
  root. Customers land there first.

## How the materials fit together

A speaker preparing this talk reads them in roughly this order:

1. The repo's root README (orientation)
2. `docs/reference/setup.md` (provision the environment, ~90 minutes,
   one time)
3. `demo-runbook.md` (the run of show, every rehearsal)
4. `one-hour-rehearsal.md` or `thirty-min-path.md` depending on time
5. Print `quick-reference.md` for the day of the talk

Customers see only the root README and `docs/architecture.md` —
that's intentional.
