// Catalog API — Agentic Developer Loop demo
// GitHub Dev Days SF, Thursday May 7, 2026.
//
// This file wires Express, Application Insights, the products router, and the
// INJECT_ERROR middleware that the Azure SRE Agent diagnoses during the
// closed-loop portion of the demo (T6 → T7 → T8).
//
// Trust boundary notes for the audience-facing demo:
//   * /products writes nothing — it is a read endpoint.
//   * INJECT_ERROR is an opt-in env var, only set on the staging slot, and
//     is propagated to production through a slot swap that Pavan triggers
//     intentionally. There is no remote toggle.
//   * The structured Application Insights message
//     "Endpoint failure detected: /products returning 500. Investigating
//     environment configuration." is the exact phrase the SRE Agent's
//     knowledge-base entry (docs/http-5xx-runbook.md) keys off of.

'use strict';

const express = require('express');
const productsRouter = require('./routes/products');

// ---- Application Insights -------------------------------------------------
// Only initialise when a connection string is present so `npm test` and local
// dev runs don't try to ship telemetry. Production picks the connection
// string up from the App Service "Application settings" injected by Bicep.
let appInsightsClient = null;
const aiConnString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;
if (aiConnString) {
  // eslint-disable-next-line global-require
  const appInsights = require('applicationinsights');
  appInsights
    .setup(aiConnString)
    .setAutoCollectConsole(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectRequests(true)
    .setAutoCollectDependencies(true)
    .setSendLiveMetrics(false)
    .start();
  appInsightsClient = appInsights.defaultClient;
  appInsightsClient.config.samplingPercentage = 100;
}

function logFailure(message, properties = {}) {
  // Console always, App Insights when available.
  // eslint-disable-next-line no-console
  console.error(JSON.stringify({ level: 'error', message, ...properties }));
  if (appInsightsClient) {
    appInsightsClient.trackTrace({
      message,
      severity: 3, // Error
      properties
    });
  }
}

// ---- App ------------------------------------------------------------------
const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '64kb' }));

// ---- INJECT_ERROR middleware ---------------------------------------------
// Trips on the staging slot when INJECT_ERROR=1. After Pavan runs
// scripts/trigger-failure.sh, a slot swap brings INJECT_ERROR=1 into
// production and every subsequent /products call returns 500. The structured
// log line below is the signal Azure SRE Agent investigates.
function injectErrorMiddleware(req, res, next) {
  if (process.env.INJECT_ERROR === '1' && req.path.startsWith('/products')) {
    logFailure(
      'Endpoint failure detected: /products returning 500. Investigating environment configuration.',
      {
        path: req.path,
        injectError: process.env.INJECT_ERROR,
        slot: process.env.WEBSITE_SLOT_NAME || 'unknown',
        siteName: process.env.WEBSITE_SITE_NAME || 'unknown'
      }
    );
    return res.status(500).json({ error: 'internal_error' });
  }
  return next();
}
app.use(injectErrorMiddleware);

// ---- Routes ---------------------------------------------------------------
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'catalog-api',
    version: process.env.GIT_SHA || 'dev',
    slot: process.env.WEBSITE_SLOT_NAME || 'local'
  });
});

app.use('/products', productsRouter);

// ---- 404 + final error handler -------------------------------------------
app.use((req, res) => {
  res.status(404).json({ error: 'not_found', path: req.path });
});

// Express 4 final error handler — keep stack traces out of responses.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, _next) => {
  logFailure('Unhandled error in request pipeline', {
    path: req.path,
    method: req.method,
    error: err && err.message
  });
  res.status(500).json({ error: 'internal_error' });
});

// ---- Start ----------------------------------------------------------------
const port = process.env.PORT || 8080;
if (require.main === module) {
  app.listen(port, () => {
    // eslint-disable-next-line no-console
    console.log(JSON.stringify({ level: 'info', message: 'catalog-api listening', port }));
  });
}

module.exports = { app, injectErrorMiddleware };
