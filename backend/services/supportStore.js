'use strict';

const { nowIso, safeId } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const tickets = new Map(); // customerId -> [ticket] (fallback)
const faqsFallback = new Map(); // id -> faq (fallback)
const SOURCES = new Set(['order', 'bag']);
const ROLES = new Set(['customer', 'restaurant', 'delivery']);
const STATUSES = new Set(['Open', 'In Progress', 'Waiting for User', 'Escalated', 'Resolved', 'Submitted']);

// Escalation routing (spec section 8).
const TEAM_BY_CATEGORY = {
  payment_refund: 'Payments / Finance',
  kyc: 'Partner Verification Team',
  settlement: 'Restaurant Finance Support',
  payout: 'Delivery Operations / Finance',
  safety: 'Priority Human Support',
  technical: 'Technical Support',
  account: 'Authorized Admin / Compliance Team',
};

function routeTeam(categoryId, role) {
  if (TEAM_BY_CATEGORY[categoryId]) return TEAM_BY_CATEGORY[categoryId];
  if (role === 'restaurant') return 'Restaurant Support';
  if (role === 'delivery') return 'Delivery Support';
  return 'Customer Support / Operations';
}

function fromRow(r) {
  return {
    id: r.id,
    source: r.source,
    categoryId: r.category_id,
    categoryLabel: r.category_label,
    createdAt: r.created_at,
    updatedAt: r.updated_at || r.created_at,
    orderId: r.order_id,
    restaurantName: r.restaurant_name,
    items: r.items || [],
    note: r.note,
    status: r.status,
    role: r.role || 'customer',
    priority: r.priority || 'normal',
    assignedTeam: r.assigned_team || null,
    resolutionNotes: r.resolution_notes || null,
  };
}

function fromFaqRow(r) {
  return {
    id: r.id,
    role: r.role,
    category: r.category,
    question: r.question,
    answer: r.answer,
    active: r.active,
    updatedAt: r.updated_at,
  };
}

async function list(customerId, { role } = {}) {
  const sb = getSupabase();
  if (!sb) {
    const rows = tickets.get(customerId) || [];
    return role ? rows.filter((t) => t.role === role) : rows;
  }
  await ensureCustomer(customerId);
  let q = sb
    .from('support_tickets')
    .select('*')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false });
  if (role) q = q.eq('role', role);
  const { data, error } = await q;
  if (error) throw dbError(error, 'support.list');
  return (data || []).map(fromRow);
}

async function create(customerId, data = {}) {
  const source = String(data.source || 'bag');
  if (!SOURCES.has(source)) return { error: 'source must be order or bag', code: 400 };
  const categoryId = String(data.categoryId || '').trim();
  if (!categoryId) return { error: 'categoryId is required', code: 400 };
  const role = String(data.role || 'customer');
  if (!ROLES.has(role)) return { error: 'role must be customer, restaurant or delivery', code: 400 };
  const priority = data.priority === 'high' ? 'high' : 'normal';
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
    role,
    priority,
    assignedTeam: routeTeam(categoryId, role),
    resolutionNotes: null,
    createdAt: nowIso(),
    updatedAt: nowIso(),
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
      role: record.role,
      priority: record.priority,
      assigned_team: record.assignedTeam,
    })
    .select('*')
    .single();
  if (error) throw dbError(error, 'support.create');
  return { ticket: fromRow(row) };
}

async function setStatus(customerId, ticketId, status, { resolutionNotes } = {}) {
  if (!STATUSES.has(status)) return { error: 'invalid status', code: 400 };
  const sb = getSupabase();
  if (!sb) {
    const list0 = tickets.get(customerId) || [];
    const t = list0.find((x) => x.id === ticketId);
    if (!t) return { error: 'ticket not found', code: 404 };
    t.status = status;
    t.updatedAt = nowIso();
    if (resolutionNotes) t.resolutionNotes = String(resolutionNotes);
    return { ticket: t };
  }
  const patch = { status, updated_at: nowIso() };
  if (resolutionNotes) patch.resolution_notes = String(resolutionNotes).slice(0, 1000);
  const { data: row, error } = await sb
    .from('support_tickets')
    .update(patch)
    .eq('id', ticketId)
    .eq('customer_id', customerId)
    .select('*')
    .single();
  if (error || !row) return { error: 'ticket not found', code: 404 };
  return { ticket: fromRow(row) };
}

async function listFaqs({ role = 'customer' } = {}) {
  const sb = getSupabase();
  if (!sb) {
    return [...faqsFallback.values()].filter((f) => f.active && f.role === role);
  }
  const { data, error } = await sb
    .from('faqs')
    .select('*')
    .eq('role', role)
    .eq('active', true)
    .order('category', { ascending: true });
  if (error) throw dbError(error, 'support.faqs');
  return (data || []).map(fromFaqRow);
}

function resetForTests() {
  tickets.clear();
  faqsFallback.clear();
}

module.exports = { list, create, setStatus, listFaqs, resetForTests, routeTeam };
