'use strict';

const crypto = require('crypto');
const orderStore = require('../services/orderStore');
const cartStore = require('../services/cartStore');
const walletStore = require('../services/walletStore');
const smartChangeStore = require('../services/smartChangeStore');
const pricingStore = require('../services/pricingStore');
const { customerIdFrom } = require('../utils/request');

function smallCartFeePaiseFor(itemSubtotalPaise) {
  if (itemSubtotalPaise <= 0) return 0;
  if (itemSubtotalPaise < 5000) return 2000;
  if (itemSubtotalPaise < 7000) return 1500;
  if (itemSubtotalPaise < 9900) return 1000;
  return 0;
}

async function computeServerBill(itemSubtotalPaise) {
  const cfg = await pricingStore.get();
  const platformFeePaise = Number(cfg.platformFeePaise || 0);
  const packagingPaise = Number(cfg.customerPackagingFeePaise || 0);
  const deliveryPaise =
    itemSubtotalPaise > 19900 ? 0 : Number(cfg.customerDeliveryFeePaise || 0);
  const taxPaise = 0; // GST included in dish prices; not charged separately
  const smallCartFeePaise = smallCartFeePaiseFor(itemSubtotalPaise);
  return { platformFeePaise, packagingPaise, deliveryPaise, taxPaise, smallCartFeePaise };
}
const { newOrderId, safeId, nowIso } = require('../utils/ids');

const METHODS = new Set(['upi', 'card', 'wallet', 'cod']);

function isNonNegInt(v) {
  return Number.isInteger(v) && v >= 0;
}

function sanitizeDeliverySnapshot(body) {
  const raw = body.deliveryAddressSnapshot;
  if (raw === undefined || raw === null) return { snapshot: null, error: null };
  if (typeof raw !== 'object' || Array.isArray(raw)) {
    return { snapshot: null, error: 'deliveryAddressSnapshot must be an object' };
  }
  const str = (v, max = 400) =>
    v === null || v === undefined ? null : String(v).trim().slice(0, max);
  const num = (v) => {
    if (v === null || v === undefined || v === '') return null;
    const n = Number(v);
    return Number.isFinite(n) ? n : null;
  };
  const lat = num(raw.latitude);
  const lng = num(raw.longitude);
  if (lat === null && lng === null) {
    return { snapshot: null, error: 'deliveryAddressSnapshot coordinates are required' };
  }
  if (lat === null) return { snapshot: null, error: 'deliveryAddressSnapshot latitude is invalid' };
  if (lng === null) return { snapshot: null, error: 'deliveryAddressSnapshot longitude is invalid' };
  if (lat < -90 || lat > 90) return { snapshot: null, error: 'deliveryAddressSnapshot latitude out of range' };
  if (lng < -180 || lng > 180) return { snapshot: null, error: 'deliveryAddressSnapshot longitude out of range' };
  return {
    snapshot: {
      id: str(raw.id, 64),
      label: str(raw.label, 32),
      name: str(raw.name, 120),
      phone: str(raw.phone, 20),
      line: str(raw.line, 300),
      city: str(raw.city, 120),
      state: str(raw.state, 120),
      landmark: str(raw.landmark, 140),
      pin: str(raw.pin, 12),
      latitude: lat,
      longitude: lng,
    },
    error: null,
  };
}

function validateBill(bill, itemSubtotalPaise, serverFees) {
  if (!bill || typeof bill !== 'object') return 'bill snapshot is required';
  const keys = [
    'itemSubtotalPaise',
    'packagingPaise',
    'deliveryPaise',
    'platformFeePaise',
    'smallCartFeePaise',
    'taxPaise',
    'tipPaise',
    'discountPaise',
    'grandTotalPaise',
  ];
  for (const key of keys) {
    if (!isNonNegInt(bill[key])) return `bill.${key} must be a non-negative integer`;
  }
  if (bill.itemSubtotalPaise !== itemSubtotalPaise) {
    return 'Bill item subtotal does not match the ordered items';
  }
  // Server-authoritative fee checks.
  if (bill.packagingPaise !== serverFees.packagingPaise) {
    return 'Bill packaging fee mismatch';
  }
  if (bill.deliveryPaise !== serverFees.deliveryPaise) {
    return 'Bill delivery fee mismatch';
  }
  if (bill.platformFeePaise !== serverFees.platformFeePaise) {
    return 'Bill platform fee mismatch';
  }
  if (bill.smallCartFeePaise !== serverFees.smallCartFeePaise) {
    return 'Bill small cart fee mismatch';
  }
  if (bill.taxPaise !== serverFees.taxPaise) {
    return 'Bill tax mismatch';
  }
  const expected =
    bill.itemSubtotalPaise +
    bill.packagingPaise +
    bill.deliveryPaise +
    bill.platformFeePaise +
    bill.smallCartFeePaise +
    bill.tipPaise -
    bill.discountPaise;
  if (expected !== bill.grandTotalPaise) {
    return 'Bill total does not match the line items and fees';
  }
  return null;
}

const checkoutController = {
  place: async (req, res) => {
    const body = req.body || {};
    const customerId = customerIdFrom(req);
    const delivery = sanitizeDeliverySnapshot(body);
    if (delivery.error) {
      return res
        .status(400)
        .json({ error: delivery.error, code: 'invalid_delivery_snapshot' });
    }
    const products = Array.isArray(body.products) ? body.products : [];
    if (products.length === 0) {
      return res.status(400).json({ error: 'products must not be empty' });
    }
    for (const p of products) {
      if (!p || p.id == null || !isNonNegInt(Number(p.price))) {
        return res.status(400).json({ error: 'Every product needs an id and a valid price' });
      }
    }
    const paymentMethod = String(body.paymentMethod || '');
    if (!METHODS.has(paymentMethod)) {
      return res.status(400).json({ error: 'paymentMethod must be upi, card, wallet or cod' });
    }

    const itemSubtotalPaise = products.reduce(
      (sum, p) => sum + Number(p.price) * 100,
      0,
    );
    const serverFees = await computeServerBill(itemSubtotalPaise);
    const bill = body.bill;
    const billError = validateBill(bill, itemSubtotalPaise, serverFees);
    if (billError) return res.status(400).json({ error: billError });

    const orderId = body.orderId ? safeId(body.orderId, 'OXRO') : newOrderId();
    const existing = await orderStore.get(orderId);
    if (existing) {
      return res.status(409).json({ error: 'Order already exists' });
    }

    const smartChangeTxnId = body.smartChangeTxnId
      ? String(body.smartChangeTxnId)
      : null;
    if (smartChangeTxnId) {
      const txn = await smartChangeStore.get(smartChangeTxnId);
      if (!txn) {
        return res.status(404).json({ error: 'Smart Change transaction not found' });
      }
      if (txn.transactionStatus !== 'order_linked' || txn.orderId !== orderId) {
        return res.status(409).json({
          error: 'Smart Change transaction is not linked to this order',
        });
      }
    }

    if (paymentMethod === 'wallet') {
      const out = await walletStore.debit(customerId, bill.grandTotalPaise, {
        txnId: `debit_${orderId}`,
        label: `Order payment ${orderId}`,
        orderId,
      });
      if (!out.ok) {
        return res.status(out.code || 409).json({ error: out.error });
      }
    }

    const ts = nowIso();
    const order = {
      id: orderId,
      customerId,
      date: 'Today',
      createdAt: ts,
      updatedAt: ts,
      status: 'processing',
      products,
      restaurantId: body.restaurantId || null,
      restaurantName: body.restaurantName || null,
      instructions: body.instructions || null,
      cutleryOptIn: body.cutleryOptIn === undefined ? null : !!body.cutleryOptIn,
      deliveredAt: null,
      bill,
      paymentMethod,
      paymentStatus: paymentMethod === 'wallet' ? 'paid' : 'pending',
      smartChangeTxnId,
      deliveryAddressSnapshot: delivery.snapshot,
    };

    const created = await orderStore.create(order);
    if (created.error) {
      if (paymentMethod === 'wallet') {
        await walletStore.credit(customerId, bill.grandTotalPaise, {
          txnId: `refund_${orderId}`,
          label: `Refund ${orderId}`,
          orderId,
        });
      }
      return res.status(created.code || 409).json({ error: created.error });
    }

    await cartStore.clear(customerId);
    return res.status(201).json({ order: created.order || order });
  },

  /** Create a Razorpay order (server-side, keeps key_secret secret). */
  createRazorpayOrder: async (req, res) => {
    const keyId = process.env.RAZORPAY_KEY_ID;
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keyId || !keySecret) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const amount = Number(req.body && req.body.amountPaise);
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(400).json({ error: 'amountPaise must be a positive integer' });
    }
    const receipt = String((req.body && req.body.receipt) || `rcpt_${Date.now()}`);
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    try {
      const r = await fetch('https://api.razorpay.com/v1/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${auth}`,
        },
        body: JSON.stringify({
          amount,
          currency: 'INR',
          receipt,
          payment_capture: 1,
        }),
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

  /** Verifies Razorpay payment signature (HMAC-SHA256). */
  verify: (req, res) => {
    const keySecret = process.env.RAZORPAY_KEY_SECRET;
    if (!keySecret) {
      return res.status(500).json({ error: 'Razorpay is not configured on the server' });
    }
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body || {};
    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return res.status(400).json({ error: 'razorpayOrderId, razorpayPaymentId and razorpaySignature are required' });
    }
    const expected = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');
    if (expected !== String(razorpaySignature)) {
      return res.status(400).json({ error: 'Payment signature verification failed', code: 'payment_verification_failed' });
    }
    return res.status(200).json({ verified: true });
  },
};

module.exports = checkoutController;
