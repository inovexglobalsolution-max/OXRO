'use strict';

const crypto = require('crypto');
const store = require('../services/dineoutStore');
const razorpay = require('../services/razorpay');
const { customerIdFrom } = require('../utils/request');
const { safeId } = require('../utils/ids');

/** The only reservation platform fee — ₹7.00, server-side constant. */
const RESERVATION_FEE_PAISE = 700;

function signaturesMatch(expected, actual) {
  const a = Buffer.from(String(expected), 'utf8');
  const b = Buffer.from(String(actual), 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

const dineoutController = {
  list: async (req, res) => {
    res.json({ bookings: await store.list(customerIdFrom(req)) });
  },

  create: async (req, res) => {
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.status(201).json({ booking: out.booking, duplicate: !!out.duplicate });
  },

  /** Creates a Razorpay order for exactly ₹7.00 — client cannot choose the amount. */
  createPaymentOrder: async (req, res) => {
    if (!razorpay.isConfigured()) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const customerId = customerIdFrom(req);
    const receipt = safeId(`dineout_${Date.now()}`, 'dineout');
    let result;
    try {
      result = await razorpay.createOrder({
        amountPaise: RESERVATION_FEE_PAISE,
        receipt,
        notes: { customerId, purpose: 'reservation_fee' },
      });
    } catch (e) {
      if (e.code === 'not_configured') {
        return res.status(500).json({ error: 'Razorpay is not configured on the server' });
      }
      return res.status(502).json({ error: 'Could not reach Razorpay' });
    }
    if (!result.ok) {
      const description =
        (result.data && result.data.error && result.data.error.description) ||
        'Razorpay order creation failed';
      return res.status(result.status).json({ error: description });
    }
    return res.status(201).json({
      razorpayOrderId: result.data.id,
      amount: result.data.amount,
      currency: result.data.currency,
      keyId: process.env.RAZORPAY_KEY_ID,
    });
  },

  /**
   * Verifies the ₹7 payment server-side, then confirms the reservation.
   * Idempotent by razorpay_payment_id. Rejects any non-₹7 charge and COD.
   */
  confirmBooking: async (req, res) => {
    if (!razorpay.isConfigured()) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    const {
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature,
      restaurantId,
      guests,
      slot,
      customerName,
      customerPhone,
      specialRequest,
    } = req.body || {};

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return res.status(400).json({
        error: 'razorpayOrderId, razorpayPaymentId and razorpaySignature are required',
      });
    }

    // 1. Signature check (timing-safe).
    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');
    if (!signaturesMatch(expected, razorpaySignature)) {
      return res.status(400).json({
        error: 'Payment signature verification failed',
        code: 'payment_verification_failed',
      });
    }

    // 2. Fetch the payment from Razorpay — never trust the client.
    let payment;
    try {
      const result = await razorpay.getPayment(razorpayPaymentId);
      if (!result.ok) {
        return res.status(400).json({
          error: 'Payment not found with Razorpay',
          code: 'payment_not_found',
        });
      }
      payment = result.data;
    } catch (e) {
      if (e.code === 'not_configured') {
        return res.status(500).json({ error: 'Razorpay is not configured on the server' });
      }
      return res.status(502).json({ error: 'Could not reach Razorpay' });
    }
    if (payment.order_id !== razorpayOrderId) {
      return res.status(400).json({
        error: 'Payment does not belong to this order',
        code: 'payment_order_mismatch',
      });
    }
    const amount = Number(payment.amount);
    if (!Number.isInteger(amount) || amount !== RESERVATION_FEE_PAISE) {
      return res.status(400).json({
        error: 'Reservation fee must be exactly ₹7.00',
        code: 'reservation_fee_mismatch',
      });
    }
    if (payment.status !== 'captured') {
      const pending = ['pending', 'created', 'authorized'].includes(payment.status);
      return res.status(409).json({
        error: pending
          ? 'Payment is still pending — the reservation will be confirmed once it is captured'
          : `Payment status is ${payment.status}`,
        code: pending ? 'payment_pending' : 'payment_failed',
        status: payment.status,
      });
    }

    // 3. Only after verification — confirm the reservation (idempotent).
    const customerId = customerIdFrom(req);
    const record = {
      restaurantId: String(restaurantId || '').trim(),
      guests,
      slot: String(slot || '').trim(),
      customerName,
      customerPhone,
      specialRequest,
      paymentId: razorpayPaymentId,
      paymentStatus: 'paid',
      amountPaise: RESERVATION_FEE_PAISE,
      bookingStatus: 'confirmed',
    };
    if (!record.restaurantId || !record.slot) {
      return res.status(400).json({ error: 'restaurantId and slot are required' });
    }
    const out = await store.create(customerId, record);
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    return res.status(201).json({
      booking: out.booking,
      duplicate: !!out.duplicate,
    });
  },
};

module.exports = dineoutController;
