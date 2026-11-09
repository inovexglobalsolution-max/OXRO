'use strict';

const crypto = require('crypto');
const store = require('../services/walletStore');
const razorpay = require('../services/razorpay');
const { customerIdFrom } = require('../utils/request');

/** Top-up bounds — must match the Flutter hint (₹10–₹50,000). */
const MIN_TOPUP_PAISE = 1000;
const MAX_TOPUP_PAISE = 5000000;

function signaturesMatch(expected, actual) {
  const a = Buffer.from(String(expected), 'utf8');
  const b = Buffer.from(String(actual), 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

function razorpayErrorStatus(res, status, data, fallback) {
  const description =
    data && data.error && data.error.description ? data.error.description : fallback;
  return res.status(status).json({ error: description });
}

const walletController = {
  get: async (req, res) => {
    res.json(await store.get(customerIdFrom(req)));
  },

  /** Legacy endpoint: top-up now goes through Razorpay create-order/verify. */
  add: (req, res) => {
    res.status(501).json({
      error: 'Use POST /wallet/create-order with Razorpay checkout.',
      code: 'topup_disabled',
    });
  },

  transactions: async (req, res) => {
    const ledger = await store.get(customerIdFrom(req));
    res.json({ transactions: ledger.transactions || [] });
  },

  createOrder: async (req, res) => {
    if (!razorpay.isConfigured()) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const amount = Number(req.body && req.body.amountPaise);
    if (!Number.isInteger(amount)) {
      return res.status(400).json({ error: 'amountPaise must be an integer' });
    }
    if (amount < MIN_TOPUP_PAISE || amount > MAX_TOPUP_PAISE) {
      return res.status(400).json({
        error: 'Top-up amount must be between ₹10 and ₹50,000',
        code: 'amount_out_of_range',
      });
    }
    const receipt = String((req.body && req.body.receipt) || `wallet_${Date.now()}`);
    const customerId = customerIdFrom(req);
    let result;
    try {
      result = await razorpay.createOrder({
        amountPaise: amount,
        receipt,
        notes: { customerId, purpose: 'wallet_topup' },
      });
    } catch (e) {
      if (e.code === 'not_configured') {
        return res.status(500).json({ error: 'Razorpay is not configured on the server' });
      }
      return res.status(502).json({ error: 'Could not reach Razorpay' });
    }
    if (!result.ok) {
      return razorpayErrorStatus(res, result.status, result.data, 'Razorpay order creation failed');
    }
    const keyId = process.env.RAZORPAY_KEY_ID;
    return res.status(201).json({
      razorpayOrderId: result.data.id,
      amount: result.data.amount,
      currency: result.data.currency,
      keyId,
    });
  },

  verifyPayment: async (req, res) => {
    if (!razorpay.isConfigured()) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body || {};
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return res
        .status(400)
        .json({ error: 'razorpayOrderId, razorpayPaymentId and razorpaySignature are required' });
    }
    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');
    if (!signaturesMatch(expected, razorpaySignature)) {
      return res
        .status(400)
        .json({ error: 'Payment signature verification failed', code: 'payment_verification_failed' });
    }

    // Signature is valid — now confirm the payment with Razorpay itself and
    // take the credited amount from Razorpay, never from the client.
    let payment;
    try {
      const result = await razorpay.getPayment(razorpayPaymentId);
      if (!result.ok) {
        return res
          .status(400)
          .json({ error: 'Payment not found with Razorpay', code: 'payment_not_found' });
      }
      payment = result.data;
    } catch (e) {
      if (e.code === 'not_configured') {
        return res.status(500).json({ error: 'Razorpay is not configured on the server' });
      }
      return res.status(502).json({ error: 'Could not reach Razorpay' });
    }
    if (payment.order_id !== razorpayOrderId) {
      return res
        .status(400)
        .json({ error: 'Payment does not belong to this order', code: 'payment_order_mismatch' });
    }
    const amt = Number(payment.amount);
    if (!Number.isInteger(amt) || amt <= 0) {
      return res.status(400).json({ error: 'Razorpay reported an invalid amount' });
    }
    if (payment.status !== 'captured') {
      const pending = ['pending', 'created', 'authorized'].includes(payment.status);
      return res.status(409).json({
        error: pending
          ? 'Payment is still pending — the wallet will be credited once it is confirmed'
          : `Payment status is ${payment.status}`,
        code: pending ? 'payment_pending' : 'payment_failed',
        status: payment.status,
      });
    }

    const customerId = customerIdFrom(req);
    const result = await store.credit(customerId, amt, {
      txnId: razorpayPaymentId,
      label: 'Wallet top-up',
      orderId: razorpayOrderId,
    });
    if (result.duplicate) {
      // Replayed callback — no second credit; report the current balance.
      const ledger = await store.get(customerId);
      return res
        .status(200)
        .json({ verified: true, duplicate: true, balancePaise: ledger.balancePaise });
    }
    if (!result.credited) return res.status(400).json({ error: result.error || 'Credit failed' });
    const balancePaise =
      result.balancePaise !== undefined
        ? result.balancePaise
        : (await store.get(customerId)).balancePaise;
    return res
      .status(200)
      .json({ verified: true, transaction: result.transaction, balancePaise });
  },

  webhook: async (req, res) => {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!secret) return res.status(500).json({ error: 'Webhook secret not configured' });
    const signature = req.headers['x-razorpay-signature'];
    const raw = req.rawBody || (Buffer.isBuffer(req.body) ? req.body : Buffer.from(JSON.stringify(req.body || {})));
    const expected = crypto.createHmac('sha256', secret).update(raw).digest('hex');
    if (!signature || !signaturesMatch(expected, signature)) {
      return res.status(400).json({ error: 'Invalid webhook signature' });
    }
    // Acknowledge; idempotent credit handled in verify endpoint.
    return res.status(200).json({ ok: true });
  },
};

module.exports = walletController;
