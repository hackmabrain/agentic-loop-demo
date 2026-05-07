# Runbook — Catalog API HTTP 5xx on `/products`

> This runbook is uploaded to the Azure SRE Agent **Knowledge Base** in
> SETUP step C8. The SRE Agent uses it to ground its investigation when
> the metric alert "alert-5xx-aldemo-*" fires.

## When this runbook applies

- Resource: any App Service named `app-aldemo-*` in
  `rg-agentic-loop-demo` (eastus2) or `rg-agentic-loop-demo-backup`
  (swedencentral).
- Trigger: Azure Monitor metric alert `alert-5xx-aldemo-*` fires.
- Symptom: `/products` returns HTTP 500 on every call. The `/` health
  endpoint still returns 200.

## What you'll see in Application Insights

- A spike in `requests` with `resultCode = 500` and
  `name = "GET /products"`.
- A correlated `traces` entry with the literal message:
  > `Endpoint failure detected: /products returning 500. Investigating environment configuration.`
- The trace properties include:
  - `injectError` — the value of the `INJECT_ERROR` environment
    variable on the slot serving the request.
  - `slot` — usually `production` when this fires.
  - `siteName` — the App Service site name.

## Most likely root cause

The production slot is serving with `INJECT_ERROR=1`. This is a demo-
mode feature flag that converts every `/products` request into HTTP 500
deliberately. It is normally only set on the **staging** slot. Bringing
it into production happens by a slot swap.

Confirm the cause:

```bash
az webapp config appsettings list \
  --resource-group <RG> \
  --name <APP_NAME> \
  --slot production \
  --query "[?name=='INJECT_ERROR'].value | [0]" -o tsv
```

If the result is `"1"`, that is the cause. The fix is to set it back
to `"0"` (or perform a reverse slot swap).

## Recommended remediation

**Option A — preferred — reverse the slot swap (restores the
previous-good production code in seconds):**

```bash
az webapp deployment slot swap \
  --resource-group <RG> \
  --name <APP_NAME> \
  --slot staging \
  --target-slot production
```

**Option B — set the flag explicitly:**

```bash
az webapp config appsettings set \
  --resource-group <RG> \
  --name <APP_NAME> \
  --slot production \
  --settings INJECT_ERROR=0
az webapp restart \
  --resource-group <RG> \
  --name <APP_NAME> \
  --slot production
```

**Verification (either option):**

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  https://<APP_NAME>.azurewebsites.net/products?category=electronics
# expect: 200
```

## What to do after restoring service

1. Open a GitHub issue in the application repo with:
   - The literal alert id and the timestamp range.
   - A link to the Application Insights query that surfaced the
     `traces` entry.
   - The recommended remediation (Option A or B).
   - Tag `sre-agent`, severity label matching the alert.
2. Do **not** change branch protection or repo settings.
3. Do **not** merge any code on the application's behalf.
4. Notify the on-call engineer (the user who last merged a PR on
   `main`).

## Related

- Source of `INJECT_ERROR`: `src/server.js` (middleware near the top).
- Slot configuration: `infra/main.bicep` (`stagingSlot` resource).
- Trigger script for the demo: `scripts/trigger-failure.sh`.
- Reset script: `scripts/reset-demo.sh`.
