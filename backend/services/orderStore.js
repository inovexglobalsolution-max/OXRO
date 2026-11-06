'use strict';

const { nowIso } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const orders = new Map(); // in-memory fallback

const STATUS_STEPS = {
  processing: 1,
  shipped: 3,
  outForDelivery: 4,
  delivered: 5,
  cancelled: 1,
};

const STEP_LABELS = [
  'Order Placed',
  'Restaurant accepted',
  'Being prepared',
  'On the way',
  'Delivered',
];

function fromRow(r) {
  if (!r) return null;
  return {
    id: r.id,
    customerId: r.customer_id,
    date: r.date,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
    status: r.status,
    products: r.products,
    restaurantId: r.restaurant_id,
    restaurantName: r.restaurant_name,
    instructions: r.instructions,
    cutleryOptIn: r.cutlery_opt_in,
    deliveredAt: r.delivered_at,
    bill: r.bill,
    paymentMethod: r.payment_method,
    paymentStatus: r.payment_status,
    smartChangeTxnId: r.smart_change_txn_id,
  };
}

function toRow(o) {
  return {
    id: o.id,
    customer_id: o.customerId,
    date: o.date || 'Today',
    status: o.status,
    products: o.products,
    restaurant_id: o.restaurantId || null,
    restaurant_name: o.restaurantName || null,
    instructions: o.instructions || null,
    cutlery_opt_in: o.cutleryOptIn === undefined ? null : o.cutleryOptIn,
    delivered_at: o.deliveredAt || null,
    bill: o.bill,
    payment_method: o.paymentMethod || null,
    payment_status: o.paymentStatus || null,
    smart_change_txn_id: o.smartChangeTxnId || null,
    created_at: o.createdAt || nowIso(),
    updated_at: o.updatedAt || nowIso(),
  };
}

async function create(order) {
  const sb = getSupabase();
  if (!sb) {
    if (orders.has(order.id)) {
      return { error: 'Order already exists', code: 409 };
    }
    orders.set(order.id, order);
    return { order };
  }
  await ensureCustomer(order.customerId);
  const { data: dup, error: dErr } = await sb
    .from('orders')
    .select('id')
    .eq('id', order.id)
    .maybeSingle();
  if (dErr) throw dbError(dErr, 'order.exists');
  if (dup) return { error: 'Order already exists', code: 409 };
  const { data, error } = await sb
    .from('orders')
    .insert(toRow(order))
    .select('*')
    .single();
  if (error) throw dbError(error, 'order.create');
  return { order: fromRow(data) };
}

async function get(id) {
  const sb = getSupabase();
  if (!sb) return orders.get(id) || null;
  const { data, error } = await sb.from('orders').select('*').eq('id', id).maybeSingle();
  if (error) throw dbError(error, 'order.get');
  return fromRow(data);
}

async function listByCustomer(customerId) {
  const sb = getSupabase();
  if (!sb) {
    return [...orders.values()]
      .filter((o) => o.customerId === customerId)
      .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
  }
  const { data, error } = await sb
    .from('orders')
    .select('*')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false });
  if (error) throw dbError(error, 'order.list');
  return (data || []).map(fromRow);
}

async function all() {
  const sb = getSupabase();
  if (!sb) return [...orders.values()];
  const { data, error } = await sb
    .from('orders')
    .select('*')
    .order('created_at', { ascending: false });
  if (error) throw dbError(error, 'order.all');
  return (data || []).map(fromRow);
}

async function updateStatus(id, status) {
  const sb = getSupabase();
  if (!sb) {
    const o = orders.get(id);
    if (!o) return { error: 'Order not found', code: 404 };
    o.status = status;
    o.updatedAt = nowIso();
    if (status === 'delivered') o.deliveredAt = o.deliveredAt || nowIso();
    return { order: o };
  }
  const patch = { status, updated_at: nowIso() };
  if (status === 'delivered') {
    const { data: cur, error: cErr } = await sb
      .from('orders')
      .select('delivered_at')
      .eq('id', id)
      .maybeSingle();
    if (cErr) throw dbError(cErr, 'order.status.read');
    if (!cur) return { error: 'Order not found', code: 404 };
    if (!cur.delivered_at) patch.delivered_at = nowIso();
  }
  const { data, error } = await sb
    .from('orders')
    .update(patch)
    .eq('id', id)
    .select('*')
    .maybeSingle();
  if (error) throw dbError(error, 'order.status');
  if (!data) return { error: 'Order not found', code: 404 };
  return { order: fromRow(data) };
}

async function cancel(id) {
  const sb = getSupabase();
  if (!sb) {
    const o = orders.get(id);
    if (!o) return { error: 'Order not found', code: 404 };
    if (o.status === 'delivered') {
      return { error: 'Delivered orders cannot be cancelled', code: 409 };
    }
    if (o.status === 'cancelled') return { order: o, duplicate: true };
    o.status = 'cancelled';
    o.updatedAt = nowIso();
    return { order: o };
  }
  const { data: o, error: rErr } = await sb
    .from('orders')
    .select('*')
    .eq('id', id)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'order.cancel.read');
  if (!o) return { error: 'Order not found', code: 404 };
  if (o.status === 'delivered') {
    return { error: 'Delivered orders cannot be cancelled', code: 409 };
  }
  if (o.status === 'cancelled') return { order: fromRow(o), duplicate: true };
  const { data, error } = await sb
    .from('orders')
    .update({ status: 'cancelled', updated_at: nowIso() })
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw dbError(error, 'order.cancel');
  return { order: fromRow(data) };
}

/** Five-step timeline derived from the stored status. */
async function trackingSteps(id) {
  const o = await get(id);
  if (!o) return null;
  const done = STATUS_STEPS[o.status] ?? 1;
  return STEP_LABELS.map((label, i) => ({
    label,
    time: i < done ? (i === 0 ? o.date : 'Done') : i === done ? 'now' : '—',
  }));
}

function resetForTests() {
  orders.clear();
}

module.exports = {
  create,
  get,
  listByCustomer,
  all,
  updateStatus,
  cancel,
  trackingSteps,
  resetForTests,
};
