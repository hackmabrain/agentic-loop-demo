// Smoke tests for the server bootstrap. These should always pass.
// node --test runs each top-level test in isolation.

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

function get(server, path, headers = {}) {
  const { port } = server.address();
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port, path, method: 'GET', headers }, (res) => {
      let body = '';
      res.on('data', (c) => { body += c; });
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.end();
  });
}

test('GET / returns 200 with status ok', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/');
    assert.equal(res.status, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.status, 'ok');
    assert.equal(body.service, 'catalog-api');
  } finally {
    server.close();
  }
});

test('GET /unknown returns 404 with not_found', async () => {
  const server = await listen();
  try {
    const res = await get(server, '/unknown');
    assert.equal(res.status, 404);
    const body = JSON.parse(res.body);
    assert.equal(body.error, 'not_found');
  } finally {
    server.close();
  }
});

test('INJECT_ERROR=1 makes /products return 500 on every call', async () => {
  const previous = process.env.INJECT_ERROR;
  process.env.INJECT_ERROR = '1';
  const server = await listen();
  try {
    const res = await get(server, '/products?category=electronics');
    assert.equal(res.status, 500);
    const body = JSON.parse(res.body);
    assert.equal(body.error, 'internal_error');
  } finally {
    server.close();
    if (previous === undefined) {
      delete process.env.INJECT_ERROR;
    } else {
      process.env.INJECT_ERROR = previous;
    }
  }
});
