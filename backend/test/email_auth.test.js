'use strict';

process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';
process.env.SUPABASE_PUBLISHABLE_KEY = '';

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const profileStore = require('../services/profileStore');
const emailAuth = require('../services/emailAuth');

let server;
let base;
let sendCalls;
let verifyCalls;
let nextSendError;
let nextVerifyError;

function mockClient() {
  return {
    auth: {
      signInWithOtp: async ({ email, options }) => {
        sendCalls.push({ email, options });
        if (nextSendError) return { data: {}, error: nextSendError };
        return { data: {}, error: null };
      },
      verifyOtp: async ({ email, token, type }) => {
        verifyCalls.push({ email, token, type });
        if (nextVerifyError) return { data: {}, error: nextVerifyError };
        return {
          data: { user: { id: 'user-123' }, session: null },
          error: null,
        };
      },
    },
  };
}

before(async () => {
  const app = require('../index');
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  emailAuth.resetForTests();
  return new Promise((resolve) => server.close(resolve));
});

beforeEach(() => {
  profileStore.resetForTests();
  emailAuth.resetForTests();
  emailAuth.setClientForTests(mockClient());
  sendCalls = [];
  verifyCalls = [];
  nextSendError = null;
  nextVerifyError = null;
});

async function call(path, body) {
  const res = await fetch(base + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

test('send-otp sends via Supabase and normalizes email', async () => {
  const { status, data } = await call('/auth/send-otp', {
    email: '  Priya@Example.COM ',
  });

  assert.equal(status, 200);
  assert.equal(data.sent, true);
  assert.equal(data.email, 'priya@example.com');
  assert.equal(sendCalls.length, 1);
  assert.equal(sendCalls[0].email, 'priya@example.com');
  assert.deepEqual(sendCalls[0].options, { shouldCreateUser: true });
});

test('send-otp rejects bad email without hitting Supabase', async () => {
  const { status, data } = await call('/auth/send-otp', { email: 'notanemail' });

  assert.equal(status, 400);
  assert.match(data.error, /valid email/i);
  assert.equal(sendCalls.length, 0);
});

test('send-otp maps Supabase rate limit to 429', async () => {
  nextSendError = { message: 'email rate limit exceeded', status: 429 };

  const { status, data } = await call('/auth/send-otp', {
    email: 'priya@example.com',
  });

  assert.equal(status, 429);
  assert.match(data.error, /Too many attempts/i);
});

test('verify-otp verifies code, upserts customer profile and returns id', async () => {
  const { status, data } = await call('/auth/verify-otp', {
    email: 'Priya@Example.com',
    token: '123456',
    name: 'Priya',
  });

  assert.equal(status, 200);
  assert.equal(data.verified, true);
  assert.equal(data.email, 'priya@example.com');
  assert.equal(data.userId, 'user-123');
  assert.equal(data.customerId, 'cust-priya@example.com');
  assert.deepEqual(verifyCalls, [
    { email: 'priya@example.com', token: '123456', type: 'email' },
  ]);

  const saved = await profileStore.get('cust-priya@example.com');
  assert.equal(saved.email, 'priya@example.com');
  assert.equal(saved.name, 'Priya');
});

test('verify-otp rejects non 6-digit tokens without hitting Supabase', async () => {
  const { status, data } = await call('/auth/verify-otp', {
    email: 'priya@example.com',
    token: '12',
  });

  assert.equal(status, 400);
  assert.match(data.error, /6-digit/i);
  assert.equal(verifyCalls.length, 0);
});

test('verify-otp maps wrong code to 401', async () => {
  nextVerifyError = { message: 'Token has expired or is invalid', status: 400 };

  const { status, data } = await call('/auth/verify-otp', {
    email: 'priya@example.com',
    token: '000000',
  });

  assert.equal(status, 401);
  assert.match(data.error, /Token has expired/i);
});
