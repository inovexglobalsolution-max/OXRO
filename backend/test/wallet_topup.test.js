'use strict';

// Tests always run against the in-memory store, even when real Supabase
// credentials exist in .env (dotenv will not override these empty values).
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';

// Razorpay credentials for the stubbed gateway — set before index.js loads
// dotenv so no test can ever reach the real Razorpay API.
process.env.RAZORPAY_KEY_ID = 'rzp_test_oxro';
process.env.RAZORPAY_KEY_SECRET = 'test_secret_0000000000000000';

const { test, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const crypto = require('node:crypto');

const walletStore = require('../services/walletStore');
const razorpay = require('../services/razorpay');

const KEY_ID = process.env.RAZORPAY_KEY_ID;
const KEY_SECRET = process.env.RAZORPAY_KEY_SECRET;

let server;
let base;

before(async () => {
  const app = require('../index');
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => {
  walletStore.resetForTests();
});

afterEach(() => {
  razorpay.setFetchForTests(null);
});

async function call(method, path, body) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

const get = (path) => call('GET', path);
const post = (path, body) => call('POST', path, body);

function sign(orderId, paymentId, secret = KEY_SECRET) {
  return crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
}

/** Routes Razorpay API calls to a stub: handler(url, opts) -> {status, body}. */
function stubRazorpay(handler) {
  razorpay.setFetchForTests(async (url, opts = {}) => {
    const result = handler(String(url), opts) || { status: 404, body: {} };
    return {
      ok: result.status >= 200 && result.status < 300,
      status: result.status,
      json: async () => result.body,
    };
  });
}

function capturedPayment(orderId, paymentId, overrides = {}) {
  return {
    id: paymentId,
    order_id: orderId,
    status: 'captured',
    amount: 10000,
    currency: 'INR',
    ...overrides,
  };
}

test('wallet create-order: amount bounds are enforced (₹10–₹50,000)', async () => {
  // Any accepted amount would hit Razorpay — the stub fails loudly instead.
  stubRazorpay(() => {
    throw new Error('Razorpay must not be called for invalid amounts');
  });
  const cases = [
    { amountPaise: 999, reason: 'below min' },
    { amountPaise: 5000001, reason: 'above max' },
    { amountPaise: 0, reason: 'zero' },
    { amountPaise: -500, reason: 'negative' },
    { amountPaise: 100.5, reason: 'non-integer' },
    { reason: 'missing' },
  ];
  for (const c of cases) {
    const { status, data } = await post('/wallet/create-order', {
      customerId: 'cust-1',
      ...(c.amountPaise === undefined ? {} : { amountPaise: c.amountPaise }),
    });
    assert.equal(status, 400, c.reason);
    assert.ok(data.error, c.reason);
  }
});

test('wallet create-order: fails cleanly when Razorpay keys are missing', async () => {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  delete process.env.RAZORPAY_KEY_ID;
  delete process.env.RAZORPAY_KEY_SECRET;
  try {
    const { status, data } = await post('/wallet/create-order', { amountPaise: 10000 });
    assert.equal(status, 500);
    assert.match(data.error, /not configured/i);
  } finally {
    process.env.RAZORPAY_KEY_ID = keyId;
    process.env.RAZORPAY_KEY_SECRET = keySecret;
  }
});

test('wallet create-order: returns 201 with order id and public key id', async () => {
  let seenBody = null;
  stubRazorpay((url, opts) => {
    assert.ok(url.endsWith('/v1/orders'), `unexpected url ${url}`);
    seenBody = JSON.parse(opts.body);
    return { status: 201, body: { id: 'order_ABC', amount: 10000, currency: 'INR' } };
  });
  const { status, data } = await post('/wallet/create-order', {
    amountPaise: 10000,
    customerId: 'cust-1',
  });
  assert.equal(status, 201);
  assert.equal(data.razorpayOrderId, 'order_ABC');
  assert.equal(data.amount, 10000);
  assert.equal(data.currency, 'INR');
  assert.equal(data.keyId, KEY_ID);
  assert.equal(seenBody.amount, 10000);
  assert.equal(seenBody.payment_capture, 1);
  assert.equal(seenBody.notes.customerId, 'cust-1');
  // The key secret must never leave the server.
  assert.equal(JSON.stringify(data).includes(KEY_SECRET), false);
});

test('wallet create-order: surfaces Razorpay order-creation errors', async () => {
  stubRazorpay(() => ({
    status: 400,
    body: { error: { description: 'Amount less than minimum' } },
  }));
  const { status, data } = await post('/wallet/create-order', { amountPaise: 10000 });
  assert.equal(status, 400);
  assert.equal(data.error, 'Amount less than minimum');
});

test('wallet verify-payment: missing fields and bad signature are rejected', async () => {
  // Signature/field validation must happen before any Razorpay lookup.
  stubRazorpay(() => {
    throw new Error('Razorpay must not be called for invalid requests');
  });
  const missing = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_ABC',
    razorpayPaymentId: 'pay_1',
  });
  assert.equal(missing.status, 400);

  const bad = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_ABC',
    razorpayPaymentId: 'pay_1',
    razorpaySignature: 'deadbeef',
    customerId: 'cust-1',
  });
  assert.equal(bad.status, 400);
  assert.equal(bad.data.code, 'payment_verification_failed');

  const wrongSecret = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_ABC',
    razorpayPaymentId: 'pay_1',
    razorpaySignature: sign('order_ABC', 'pay_1', 'some-other-secret'),
    customerId: 'cust-1',
  });
  assert.equal(wrongSecret.status, 400);
  assert.equal(wrongSecret.data.code, 'payment_verification_failed');

  assert.equal((await get('/wallet?customerId=cust-1')).data.balancePaise, 0);
});

test('wallet verify-payment: captured payment credits the right customer', async () => {
  stubRazorpay((url) => {
    assert.ok(url.includes('/v1/payments/pay_OK'), `unexpected url ${url}`);
    return { status: 200, body: capturedPayment('order_ABC', 'pay_OK') };
  });
  const { status, data } = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_ABC',
    razorpayPaymentId: 'pay_OK',
    razorpaySignature: sign('order_ABC', 'pay_OK'),
    customerId: 'cust-1',
    // Hostile/buggy client amount — must be ignored.
    amountPaise: 99999900,
  });
  assert.equal(status, 200);
  assert.equal(data.verified, true);
  assert.equal(data.transaction.amountPaise, 10000);
  assert.equal(data.transaction.id, 'pay_OK');
  assert.equal(data.balancePaise, 10000);

  const ledger = await get('/wallet?customerId=cust-1');
  assert.equal(ledger.data.balancePaise, 10000);
  assert.equal(ledger.data.transactions.length, 1);
  assert.equal(ledger.data.transactions[0].id, 'pay_OK');
  assert.equal(ledger.data.transactions[0].label, 'Wallet top-up');

  // Payment is linked to the authenticated user, not a shared bucket.
  const other = await get('/wallet?customerId=cust-2');
  assert.equal(other.data.balancePaise, 0);
  assert.equal(other.data.transactions.length, 0);
});

test('wallet verify-payment: duplicate callback never double-credits', async () => {
  stubRazorpay(() => ({ status: 200, body: capturedPayment('order_DUP', 'pay_DUP') }));
  const body = {
    razorpayOrderId: 'order_DUP',
    razorpayPaymentId: 'pay_DUP',
    razorpaySignature: sign('order_DUP', 'pay_DUP'),
    customerId: 'cust-1',
  };
  const first = await post('/wallet/verify-payment', body);
  assert.equal(first.status, 200);
  assert.equal(first.data.duplicate, undefined);
  assert.equal(first.data.balancePaise, 10000);

  // Razorpay replays the same callback twice.
  const second = await post('/wallet/verify-payment', body);
  assert.equal(second.status, 200);
  assert.equal(second.data.duplicate, true);
  assert.equal(second.data.balancePaise, 10000);

  const third = await post('/wallet/verify-payment', body);
  assert.equal(third.status, 200);
  assert.equal(third.data.duplicate, true);

  const ledger = await get('/wallet?customerId=cust-1');
  assert.equal(ledger.data.balancePaise, 10000);
  assert.equal(ledger.data.transactions.length, 1);
});

test('wallet verify-payment: pending payment is not credited', async () => {
  stubRazorpay(() => ({
    status: 200,
    body: capturedPayment('order_PEND', 'pay_PEND', { status: 'pending' }),
  }));
  const { status, data } = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_PEND',
    razorpayPaymentId: 'pay_PEND',
    razorpaySignature: sign('order_PEND', 'pay_PEND'),
    customerId: 'cust-1',
  });
  assert.equal(status, 409);
  assert.equal(data.code, 'payment_pending');
  const ledger = await get('/wallet?customerId=cust-1');
  assert.equal(ledger.data.balancePaise, 0);
  assert.equal(ledger.data.transactions.length, 0);
});

test('wallet verify-payment: failed payment is not credited', async () => {
  stubRazorpay(() => ({
    status: 200,
    body: capturedPayment('order_FAIL', 'pay_FAIL', { status: 'failed' }),
  }));
  const { status, data } = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_FAIL',
    razorpayPaymentId: 'pay_FAIL',
    razorpaySignature: sign('order_FAIL', 'pay_FAIL'),
    customerId: 'cust-1',
  });
  assert.equal(status, 409);
  assert.equal(data.code, 'payment_failed');
  assert.equal((await get('/wallet?customerId=cust-1')).data.balancePaise, 0);
});

test('wallet verify-payment: payment from another order is rejected', async () => {
  stubRazorpay(() => ({ status: 200, body: capturedPayment('order_OTHER', 'pay_X') }));
  const { status, data } = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_ABC',
    razorpayPaymentId: 'pay_X',
    razorpaySignature: sign('order_ABC', 'pay_X'),
    customerId: 'cust-1',
  });
  assert.equal(status, 400);
  assert.equal(data.code, 'payment_order_mismatch');
  assert.equal((await get('/wallet?customerId=cust-1')).data.balancePaise, 0);
});

test('wallet verify-payment: unknown payment is rejected', async () => {
  stubRazorpay(() => ({ status: 404, body: { error: { description: 'payment does not exist' } } }));
  const { status, data } = await post('/wallet/verify-payment', {
    razorpayOrderId: 'order_ABC',
    razorpayPaymentId: 'pay_GONE',
    razorpaySignature: sign('order_ABC', 'pay_GONE'),
    customerId: 'cust-1',
  });
  assert.equal(status, 400);
  assert.equal(data.code, 'payment_not_found');
  assert.equal((await get('/wallet?customerId=cust-1')).data.balancePaise, 0);
});

test('wallet /add stays disabled (legacy endpoint)', async () => {
  const { status, data } = await post('/wallet/add', { customerId: 'cust-1', amount: 100 });
  assert.equal(status, 501);
  assert.equal(data.code, 'topup_disabled');
});
