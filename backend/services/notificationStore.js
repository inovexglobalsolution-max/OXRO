'use strict';

const { nowIso, safeId } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const seed = []; // fallback inbox (matches the app's original seed rows)
const KINDS = new Set(['order', 'offer']);

function fromRow(r) {
  return {
    id: r.id,
    title: r.title,
    sub: r.sub,
    time: r.time,
    icon: r.icon,
    kind: r.kind,
    unread: r.unread,
  };
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) return seed.map((n) => ({ ...n }));
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('notifications')
    .select('*')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false });
  if (error) throw dbError(error, 'notifications.list');
  return (data || []).map(fromRow);
}

async function create(customerId, data = {}) {
  const kind = KINDS.has(data.kind) ? data.kind : 'order';
  const record = {
    id: safeId(data.id, 'ntf'),
    title: String(data.title || '').slice(0, 120),
    sub: String(data.sub || '').slice(0, 200),
    time: String(data.time || 'now'),
    icon: Number.isInteger(Number(data.icon)) ? Number(data.icon) : 0,
    kind,
    unread: true,
    createdAt: nowIso(),
  };
  if (!record.title) return { error: 'title is required', code: 400 };

  const sb = getSupabase();
  if (!sb) {
    seed.unshift(record);
    return { notification: record };
  }
  await ensureCustomer(customerId);
  const { data: row, error } = await sb
    .from('notifications')
    .insert({
      id: record.id,
      customer_id: customerId,
      title: record.title,
      sub: record.sub,
      kind: record.kind,
      icon: record.icon,
      time: record.time,
      unread: true,
    })
    .select('*')
    .single();
  if (error) throw dbError(error, 'notifications.create');
  return { notification: fromRow(row) };
}

async function markRead(customerId, id, unread) {
  const sb = getSupabase();
  if (!sb) {
    const n = seed.find((x) => x.id === id);
    if (!n) return { error: 'Notification not found', code: 404 };
    n.unread = !!unread;
    return { notification: { ...n } };
  }
  const { data, error } = await sb
    .from('notifications')
    .update({ unread: !!unread })
    .eq('customer_id', customerId)
    .eq('id', id)
    .select('*')
    .maybeSingle();
  if (error) throw dbError(error, 'notifications.markRead');
  if (!data) return { error: 'Notification not found', code: 404 };
  return { notification: fromRow(data) };
}

async function markAllRead(customerId) {
  const sb = getSupabase();
  if (!sb) {
    for (const n of seed) n.unread = false;
    return { updated: seed.length };
  }
  const { data, error } = await sb
    .from('notifications')
    .update({ unread: false })
    .eq('customer_id', customerId)
    .select('id');
  if (error) throw dbError(error, 'notifications.markAllRead');
  return { updated: (data || []).length };
}

function resetForTests() {
  seed.length = 0;
}

module.exports = { list, create, markRead, markAllRead, resetForTests };
