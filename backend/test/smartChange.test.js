'use strict';

// Tests always run against the in-memory store, even when real Supabase
// credentials exist in .env (dotenv will not override these empty values).
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const store = require('../services/smartChangeStore');

let server;
let base;

const ORDER = 32000; // ₹320
const CASH = 50000; // ₹500
const CHANGE = 18000; // ₹180

before(async () => {
  const app = require('../index');
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));
beforeEach(() => store.resetForTests());

async function post(path, body) {
  const res = await fetch(base + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function get(path) {
  const res = await fetch(base + path);
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function activate(key = 'idem-1', order = ORDER, cash = CASH) {
  return post('/smart-change/activate', {
    customerId: 'cust-1',
    orderAmountPaise: order,
    cashAmountPaise: cash,
    idempotencyKey: key,
  });
}

async function activateAndLink() {
  const a = await activate();
  assert.equal(a.status, 201);
  const l = await post(`/smart-change/${a.data.txnId}/link-order`, {
    orderId: 'OXRO123457',
  });
  assert.equal(l.status, 200);
  return a.data.txnId;
}

test('activate: ₹320 order + ₹500 cash → ₹180 change (server-side math)', async () => {
  const { status, data } = await activate();
  assert.equal(status, 201);
  assert.match(data.txnId, /^SC/);
  assert.equal(data.remainingChangePaise, CHANGE);
  assert.equal(data.transactionStatus, 'activated');
  assert.equal(data.consentStatus, 'granted');
});

test('activate: invalid cash below order amount is rejected', async () => {
  const { status, data } = await activate('bad-1', ORDER, 10000);
  assert.equal(status, 400);
  assert.match(data.error, /equal to or greater than/i);
});

test('activate: negative / non-positive amounts are rejected', async () => {
  const neg = await activate('bad-2', ORDER, -500);
  assert.equal(neg.status, 400);
  const zero = await activate('bad-3', 0, CASH);
  assert.equal(zero.status, 400);
});

test('activate: duplicate idempotency key returns the same transaction', async () => {
  const first = await activate('dup-1');
  const second = await activate('dup-1');
  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.equal(second.data.txnId, first.data.txnId);
  assert.equal(second.data.duplicate, true);
});

test('activate: idempotency key reused with a different payload conflicts', async () => {
  await activate('mix-1', ORDER, CASH);
  const clash = await activate('mix-1', ORDER, CASH + 100);
  assert.equal(clash.status, 409);
});

test('link-order: idempotent; different order id conflicts', async () => {
  const a = await activate();
  const first = await post(`/smart-change/${a.data.txnId}/link-order`, {
    orderId: 'OXRO111',
  });
  assert.equal(first.status, 200);
  assert.equal(first.data.transactionStatus, 'order_linked');

  const again = await post(`/smart-change/${a.data.txnId}/link-order`, {
    orderId: 'OXRO111',
  });
  assert.equal(again.status, 200);
  assert.equal(again.data.duplicate, true);

  const clash = await post(`/smart-change/${a.data.txnId}/link-order`, {
    orderId: 'OXRO222',
  });
  assert.equal(clash.status, 409);
});

test('collect before link is rejected', async () => {
  const a = await activate();
  const { status } = await post(`/smart-change/${a.data.txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  assert.equal(status, 409);
});

test('collect: credits exact change with wallet transaction id', async () => {
  const txnId = await activateAndLink();
  const { status, data } = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  assert.equal(status, 200);
  assert.equal(data.transactionStatus, 'credited');
  assert.equal(data.remainingChangePaise, CHANGE);
  assert.match(data.walletTransactionId, /^WTX/);
  assert.equal(data.partnerId, 'rider-1');
});

test('collect: actual cash below order amount is rejected', async () => {
  const txnId = await activateAndLink();
  const { status } = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: ORDER - 1,
  });
  assert.equal(status, 400);
});

test('collect: duplicate request never double-credits', async () => {
  const txnId = await activateAndLink();
  const first = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  const second = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-2',
    actualCashPaise: CASH + 5000,
  });
  assert.equal(first.status, 200);
  assert.equal(second.status, 200);
  assert.equal(second.data.duplicate, true);
  // Original credit is immutable — partner cannot increase it.
  assert.equal(second.data.walletTransactionId, first.data.walletTransactionId);
  assert.equal(second.data.remainingChangePaise, CHANGE);
});

test('collect: concurrent requests resolve to one credit', async () => {
  const txnId = await activateAndLink();
  const results = await Promise.all(
    Array.from({ length: 5 }, (_, i) =>
      post(`/smart-change/${txnId}/collect`, {
        partnerId: `rider-${i}`,
        actualCashPaise: CASH,
      }),
    ),
  );
  const ids = new Set(
    results.map((r) => r.data.walletTransactionId).filter(Boolean),
  );
  assert.equal(ids.size, 1); // exactly one wallet transaction id
  for (const r of results) assert.equal(r.status, 200);
});

test('failed wallet credit stays pending — never marked successful', async () => {
  const txnId = await activateAndLink();
  store.setFailNextCredit(true);
  const fail = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  assert.equal(fail.status, 502);
  assert.equal(fail.data.transactionStatus, 'credit_pending');
  assert.equal(fail.data.walletTransactionId, null);

  // Reconciliation retry succeeds and records the credit.
  const retry = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  assert.equal(retry.status, 200);
  assert.equal(retry.data.transactionStatus, 'credited');
  assert.match(retry.data.walletTransactionId, /^WTX/);
});

test('cancelled transaction: collect rejected — no unauthorized credit', async () => {
  const txnId = await activateAndLink();
  const c = await post(`/smart-change/${txnId}/cancel`, {});
  assert.equal(c.status, 200);
  assert.equal(c.data.transactionStatus, 'cancelled');
  const collect = await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  assert.equal(collect.status, 409);
});

test('GET status + credited list for customer', async () => {
  const txnId = await activateAndLink();
  await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  const one = await get(`/smart-change/${txnId}`);
  assert.equal(one.status, 200);
  assert.equal(one.data.transactionStatus, 'credited');

  const list = await get('/smart-change/credited?customerId=cust-1');
  assert.equal(list.status, 200);
  assert.equal(list.data.transactions.length, 1);
  assert.equal(list.data.transactions[0].txnId, txnId);
});

test('collectable: lists linked orders; leaves after collection', async () => {
  // Activated-only (not linked) is not collectable.
  const a = await activate('coll-1');
  assert.equal(a.status, 201);

  const txnId = await activateAndLink();
  const before = await get('/smart-change/collectable');
  assert.equal(before.status, 200);
  assert.equal(before.data.transactions.length, 1);
  assert.equal(before.data.transactions[0].txnId, txnId);
  assert.equal(before.data.transactions[0].orderId, 'OXRO123457');
  assert.equal(before.data.transactions[0].declaredCashPaise, CASH);
  assert.equal(before.data.transactions[0].remainingChangePaise, CHANGE);

  // After a successful collect it disappears from the partner list.
  await post(`/smart-change/${txnId}/collect`, {
    partnerId: 'rider-1',
    actualCashPaise: CASH,
  });
  const after = await get('/smart-change/collectable');
  assert.equal(after.status, 200);
  assert.equal(after.data.transactions.length, 0);
});
