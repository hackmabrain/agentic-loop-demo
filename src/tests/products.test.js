// Tests for /products.
//
// THE FAILING TEST:
//   `GET /products without category returns 200 and the full catalog`
// This test currently FAILS because of the seeded bug in routes/products.js:
//   const category = req.query.category.toLowerCase();
// throws TypeError when called without a query string.
//
// GitHub Copilot Coding Agent's job during the demo:
//   1. Run `npm test` and see this test fail.
//   2. Fix routes/products.js so the no-category path returns the full
//      catalog with HTTP 200.
//   3. Add input validation that rejects unknown categories with HTTP 400.
//   4. Open a PR with the fix and a passing test suite.

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const { app } = require('../server');

function listen() {
  return new Promise((resolve) => {
    const server = http.createServer(app).listen(0, () => resolve(server));
  });
}

function get(server, path) {
  const { port } = server.address();
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path, method: 'GET' }, (res) => {
      let body = '';
      res.on('data', (c) => { body += c; });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

test('GET /products?category=electronics returns the electronics list', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/products?category=electronics');
    assert.equal(res.status, 200);
    const body = JSON.parse(res.body);
    assert.ok(Array.isArray(body), 'expected an array');
    assert.ok(body.length > 0, 'expected at least one electronics product');
    assert.ok(body.every((p) => p.category === 'electronics'));
  } finally {
    server.close();
  }
});

// FAILING-BY-DESIGN: this is the test the Coding Agent will make pass.
test('GET /products without category returns 200 and the full catalog', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/products');
    assert.equal(res.status, 200, 'expected 200; the seeded bug returns 500');
    const body = JSON.parse(res.body);
    assert.ok(Array.isArray(body));
    assert.ok(body.length >= 8, 'expected the full catalog (>=8 items)');
  } finally {
    server.close();
  }
});

// Tightened from a loose 200/400 pin to assert 400 unambiguously. The
// issue body's acceptance criteria require unknown categories to be
// rejected with HTTP 400 (input validation). Pre-fix this test fails
// alongside the no-category test — the Coding Agent's PR makes both
// pass at once, and the audience sees a fix that's clearly correct.
test('GET /products?category=does-not-exist returns 400 (input validation)', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/products?category=does-not-exist');
    assert.equal(res.status, 400, 'expected 400 — unknown category should be rejected with input validation');
  } finally {
    server.close();
  }
});

test('GET /products/:id returns the product when found', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/products/p-001');
    assert.equal(res.status, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.id, 'p-001');
  } finally {
    server.close();
  }
});

test('GET /products/:id returns 404 when not found', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/products/does-not-exist');
    assert.equal(res.status, 404);
  } finally {
    server.close();
  }
});
