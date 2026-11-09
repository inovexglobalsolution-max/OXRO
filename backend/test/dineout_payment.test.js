'use strict';

// Reservation platform fee (₹7) — in-memory only.
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';
process.env.RAZORPAY_KEY_ID = 'rzp_test_oxro';
process.env.RAZORPAY_KEY_SECRET = 'test_secret_0000000000000000';

const { test, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const crypto = require('node:crypto');

const dineoutStore = require('../services/dineoutStore');
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
  dineoutStore.resetForTests();
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

const get = (p) => call('GET', p);
const post = (p, b) => call('POST', p, b);

function sign(orderId, paymentId, secret = KEY_SECRET) {
  return crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
}

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

test('create-payment-order: server enforces exactly ₹7.00', async () => {
  stubRazorpay((url, opts) => {
    const body = JSON.parse(opts.body || '{}');
    assert.equal(body.amount, 700);
    return {
      status: 201,
      body: { id: 'order_RES001', amount: 700, currency: 'INR' },
    };
  });
  const { status, data } = await post('/dineout/bookings/create-payment-order', {
    customerId: 'cust-res',
  });
  assert.equal(status, 201);
  assert.equal(data.razorpayOrderId, 'order_RES001');
  assert.equal(data.amount, 700);
  assert.equal(data.currency, 'INR');
  assert.equal(data.keyId, KEY_ID);
});

test('confirm-booking: verifies signature, amount and status; creates booking once', async () => {
  stubRazorpay(() => ({
    status: 200,
    body: {
      id: 'pay_RES001',
      order_id: 'order_RES001',
      status: 'captured',
      amount: 700,
      currency: 'INR',
    },
  }));
  const body = {
    razorpayOrderId: 'order_RES001',
    razorpayPaymentId: 'pay_RES001',
    razorpaySignature: sign('order_RES001', 'pay_RES001'),
    restaurantId: 'd_verandah',
    guests: 4,
    slot: '8:00 PM',
    customerId: 'cust-res',
  };
  const first = await post('/dineout/bookings/confirm-booking', body);
  assert.equal(first.status, 201);
  assert.equal(first.data.booking.paymentStatus, 'paid');
  assert.equal(first.data.booking.amountPaise, 700);
  assert.equal(first.data.booking.guests, 4);
  assert.equal(first.data.booking.slot, '8:00 PM');

  // Duplicate callback — must not create a second booking.
  const second = await post('/dineout/bookings/confirm-booking', body);
  assert.equal(second.status, 201);
  assert.equal(second.data.duplicate, true);
  const listed = await get('/dineout/bookings?customerId=cust-res');
  assert.equal(listed.data.bookings.length, 1);
});

test('confirm-booking: wrong amount rejected', async () => {
  stubRazorpay(() => ({
    status: 200,
    body: { id: 'pay_RES002', order_id: 'order_RES002', status: 'captured', amount: 5000 },
  }));
  const { status, data } = await post('/dineout/bookings/confirm-booking', {
    razorpayOrderId: 'order_RES002',
    razorpayPaymentId: 'pay_RES002',
    razorpaySignature: sign('order_RES002', 'pay_RES002'),
    restaurantId: 'd_verandah',
    guests: 2,
    slot: '7:00 PM',
    customerId: 'cust-res',
  });
  assert.equal(status, 400);
  assert.equal(data.code, 'reservation_fee_mismatch');
});

test('confirm-booking: bad signature rejected', async () => {
  const { status, data } = await post('/dineout/bookings/confirm-booking', {
    razorpayOrderId: 'order_RES003',
    razorpayPaymentId: 'pay_RES003',
    razorpaySignature: 'deadbeef',
    restaurantId: 'd_verandah',
    guests: 2,
    slot: '7:00 PM',
    customerId: 'cust-res',
  });
  assert.equal(status, 400);
  assert.equal(data.code, 'payment_verification_failed');
});

test('confirm-booking: pending payment not confirmed', async () => {
  stubRazorpay(() => ({
    status: 200,
    body: { id: 'pay_RES004', order_id: 'order_RES004', status: 'pending', amount: 700 },
  }));
  const { status, data } = await post('/dineout/bookings/confirm-booking', {
    razorpayOrderId: 'order_RES004',
    razorpayPaymentId: 'pay_RES004',
    razorpaySignature: sign('order_RES004', 'pay_RES004'),
    restaurantId: 'd_verandah',
    guests: 2,
    slot: '7:00 PM',
    customerId: 'cust-res',
  });
  assert.equal(status, 409);
  assert.equal(data.code, 'payment_pending');
  assert.equal((await get('/dineout/bookings?customerId=cust-res')).data.bookings.length, 0);
});

test('confirm-booking: payment with mismatched order rejected', async () => {
  stubRazorpay(() => ({
    status: 200,
    body: { id: 'pay_RES005', order_id: 'order_OTHER', status: 'captured', amount: 700 },
  }));
  const { status, data } = await post('/dineout/bookings/confirm-booking', {
    razorpayOrderId: 'order_RES005',
    razorpayPaymentId: 'pay_RES005',
    razorpaySignature: sign('order_RES005', 'pay_RES005'),
    restaurantId: 'd_verandah',
    guests: 2,
    slot: '7:00 PM',
    customerId: 'cust-res',
  });
  assert.equal(status, 400);
  assert.equal(data.code, 'payment_order_mismatch');
});
