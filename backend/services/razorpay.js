'use strict';

/**
 * Thin Razorpay REST wrapper (orders + payments) using the server-side
 * key pair from the environment. The key secret never leaves this process.
 *
 * `fetchImpl` is swappable so tests can stub Razorpay without touching the
 * global fetch the test harness itself uses.
 */

const API_BASE = 'https://api.razorpay.com/v1';

let fetchImpl = globalThis.fetch;

function setFetchForTests(fn) {
  fetchImpl = fn || globalThis.fetch;
}

function isConfigured() {
  return Boolean(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET);
}

function authHeader() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) return null;
  return `Basic ${Buffer.from(`${keyId}:${keySecret}`).toString('base64')}`;
}

/**
 * @returns {Promise<{ok: boolean, status: number, data: object}>}
 * @throws {{code: 'not_configured'|'unreachable'}}
 */
async function call(path, { method = 'GET', body } = {}) {
  const auth = authHeader();
  if (!auth) {
    const err = new Error('Razorpay is not configured on the server');
    err.code = 'not_configured';
    throw err;
  }
  let res;
  try {
    res = await fetchImpl(`${API_BASE}${path}`, {
      method,
      headers: { 'Content-Type': 'application/json', Authorization: auth },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (_) {
    const err = new Error('Could not reach Razorpay');
    err.code = 'unreachable';
    throw err;
  }
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}

/** Creates a Razorpay order. `notes` lands on the order for reconciliation. */
function createOrder({ amountPaise, receipt, notes } = {}) {
  return call('/orders', {
    method: 'POST',
    body: {
      amount: amountPaise,
      currency: 'INR',
      receipt,
      payment_capture: 1,
      ...(notes ? { notes } : {}),
    },
  });
}

/** Fetches a payment (amount, order_id, status) — the authoritative record. */
function getPayment(paymentId) {
  return call(`/payments/${encodeURIComponent(paymentId)}`);
}

module.exports = { isConfigured, createOrder, getPayment, setFetchForTests };
