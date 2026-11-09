'use strict';

const { safeId, nowIso } = require('../utils/ids');
const { getSupabase, dbError } = require('../db/helpers');

const inMemory = new Map(); // orderId -> [{id, senderRole, body, createdAt}]

function fromRow(r) {
  return {
    id: r.id,
    senderRole: r.sender_role,
    body: r.body,
    createdAt: r.created_at,
  };
}

async function list(orderId) {
  const sb = getSupabase();
  if (!sb) {
    return { messages: inMemory.get(orderId) || [] };
  }
  const { data, error } = await sb
    .from('order_messages')
    .select('*')
    .eq('order_id', orderId)
    .order('created_at', { ascending: true });
  if (error) {
    return { error: dbError(error, 'messages.list').message, code: 502 };
  }
  return { messages: (data || []).map(fromRow) };
}

async function send(orderId, senderRole, body) {
  const id = safeId(`MSG${Date.now()}${Math.floor(Math.random() * 1000)}`, 'MSG');
  const createdAt = nowIso();
  const sb = getSupabase();
  if (!sb) {
    const listArr = inMemory.get(orderId) || [];
    const message = { id, senderRole, body, createdAt };
    listArr.push(message);
    inMemory.set(orderId, listArr);
    return { message };
  }
  const { data, error } = await sb
    .from('order_messages')
    .insert({ id, order_id: orderId, sender_role: senderRole, body, created_at: createdAt })
    .select('*')
    .single();
  if (error) {
    return { error: dbError(error, 'messages.send').message, code: 502 };
  }
  return { message: fromRow(data) };
}

function resetForTests() {
  inMemory.clear();
}

module.exports = { list, send, resetForTests };
