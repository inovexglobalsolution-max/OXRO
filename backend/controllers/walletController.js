'use strict';

const crypto = require('crypto');
const store = require('../services/walletStore');
const { customerIdFrom } = require('../utils/request');

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
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keyId || !keySecret) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const amount = Number(req.body && req.body.amountPaise);
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({ error: 'amountPaise must be a positive integer' });
    }
    const receipt = String((req.body && req.body.receipt) || `wallet_${Date.now()}`);
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    try {
      const r = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Basic ${auth}` },
        body: JSON.stringify({ amount, currency: 'INR', receipt, payment_capture: 1 }),
      });
      const data = await r.json().catch(() => ({}));
      if (!r.ok) {
        return res.status(r.status).json({ error: (data && data.error && data.error.description) ? data.error.description : 'Razorpay order creation failed' });
      }
      return res.status(201).json({ razorpayOrderId: data.id, amount: data.amount, currency: data.currency, keyId });
    } catch (e) {
      return res.status(502).json({ error: 'Could not reach Razorpay' });
    }
  },

  verifyPayment: async (req, res) => {
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keySecret) return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature, amountPaise } = req.body || {};
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return res.status(400).json({ error: 'razorpayOrderId, razorpayPaymentId and razorpaySignature are required' });
    }
    const expected = crypto.createHmac('sha256', keySecret).update(`${razorpayOrderId}|${razorpayPaymentId}`).digest('hex');
    if (expected !== String(razorpaySignature)) {
      return res.status(400).json({ error: 'Payment signature verification failed', code: 'payment_verification_failed' });
    }
    const customerId = customerIdFrom(req);
    const amt = Number(amountPaise);
    if (!Number.isInteger(amt) || amt <= 0) {
      return res.status(400).json({ error: 'amountPaise must be a positive integer' });
    }
    const result = await store.credit(customerId, amt, { txnId: razorpayPaymentId, label: 'Wallet top-up', orderId: razorpayOrderId });
    if (result.duplicate) return res.status(200).json({ verified: true, duplicate: true, balancePaise: result.balancePaise });
    if (!result.credited) return res.status(400).json({ error: result.error || 'Credit failed' });
    return res.status(200).json({ verified: true, transaction: result.transaction, balancePaise: result.balancePaise });
  },

  webhook: async (req, res) => {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!secret) return res.status(500).json({ error: 'Webhook secret not configured' });
    const signature = req.headers['x-razorpay-signature'];
    const raw = req.rawBody || (Buffer.isBuffer(req.body) ? req.body : Buffer.from(JSON.stringify(req.body || {})));
    const expected = crypto.createHmac('sha256', secret).update(raw).digest('hex');
    if (!signature || expected !== String(signature)) {
      return res.status(400).json({ error: 'Invalid webhook signature' });
    }
    // Acknowledge; idempotent credit handled in verify endpoint.
    return res.status(200).json({ ok: true });
  },
};

module.exports = walletController;
