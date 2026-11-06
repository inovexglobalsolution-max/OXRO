'use strict';

const { nowIso, safeId } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const tickets = new Map(); // customerId -> [ticket] (fallback)
const SOURCES = new Set(['order', 'bag']);

function fromRow(r) {
  return {
    id: r.id,
    source: r.source,
    categoryId: r.category_id,
    categoryLabel: r.category_label,
    createdAt: r.created_at,
    orderId: r.order_id,
    restaurantName: r.restaurant_name,
    items: r.items || [],
    note: r.note,
    status: r.status,
  };
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) return tickets.get(customerId) || [];
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('support_tickets')
    .select('*')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false });
  if (error) throw dbError(error, 'support.list');
  return (data || []).map(fromRow);
}

async function create(customerId, data = {}) {
  const source = String(data.source || 'bag');
  if (!SOURCES.has(source)) return { error: 'source must be order or bag', code: 400 };
  const categoryId = String(data.categoryId || '').trim();
  if (!categoryId) return { error: 'categoryId is required', code: 400 };
  const record = {
    id: safeId(data.id, 'tkt'),
    source,
    categoryId,
    categoryLabel: String(data.categoryLabel || 'Other'),
    orderId: data.orderId || null,
    restaurantName: data.restaurantName || null,
    items: Array.isArray(data.items) ? data.items.filter((x) => typeof x === 'string') : [],
    note: String(data.note || '').slice(0, 500),
    status: 'Submitted',
    createdAt: nowIso(),
  };

  const sb = getSupabase();
  if (!sb) {
    const list0 = tickets.get(customerId) || [];
    list0.unshift(record);
    tickets.set(customerId, list0);
    return { ticket: record };
  }
  await ensureCustomer(customerId);
  const { data: row, error } = await sb
    .from('support_tickets')
    .insert({
      id: record.id,
      customer_id: customerId,
      source: record.source,
      category_id: record.categoryId,
      category_label: record.categoryLabel,
      order_id: record.orderId,
      restaurant_name: record.restaurantName,
      items: record.items,
      note: record.note,
      status: record.status,
    })
    .select('*')
    .single();
  if (error) throw dbError(error, 'support.create');
  return { ticket: fromRow(row) };
}

function resetForTests() {
  tickets.clear();
}

module.exports = { list, create, resetForTests };
