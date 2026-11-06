'use strict';

const { safeId } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const books = new Map(); // in-memory fallback

function book(customerId) {
  let b = books.get(customerId);
  if (!b) {
    b = { items: new Map(), defaultId: null };
    books.set(customerId, b);
  }
  return b;
}

function view(a) {
  return {
    id: a.id,
    label: a.label,
    name: a.name,
    phone: a.phone,
    line: a.line,
    city: a.city,
    pin: a.pin,
  };
}

function fromRow(r) {
  return {
    id: r.id,
    label: r.label,
    name: r.name,
    phone: r.phone,
    line: r.line,
    city: r.city,
    pin: r.pin,
  };
}

function normalize(data = {}) {
  return {
    label: String(data.label || 'Home').trim() || 'Home',
    name: String(data.name || '').trim(),
    phone: String(data.phone || '').trim(),
    line: String(data.line || '').trim(),
    city: String(data.city || '').trim(),
    pin: String(data.pin || '').trim(),
  };
}

async function _defaultId(sb, customerId) {
  const { data, error } = await sb
    .from('customers')
    .select('default_address_id')
    .eq('customer_id', customerId)
    .maybeSingle();
  if (error) throw dbError(error, 'address.default');
  return data ? data.default_address_id : null;
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) {
    const b = book(customerId);
    return {
      addresses: [...b.items.values()].map(view),
      defaultId: b.defaultId,
    };
  }
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('addresses')
    .select('*')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: true });
  if (error) throw dbError(error, 'address.list');
  return {
    addresses: (data || []).map(fromRow),
    defaultId: await _defaultId(sb, customerId),
  };
}

async function create(customerId, data = {}) {
  const sb = getSupabase();
  if (!sb) {
    const b = book(customerId);
    const id = safeId(data.id, 'addr');
    if (b.items.has(id)) return { error: 'Address already exists', code: 409 };
    const address = { id, ...normalize(data) };
    b.items.set(id, address);
    if (b.defaultId == null) b.defaultId = id;
    return { address };
  }
  await ensureCustomer(customerId);
  const id = safeId(data.id, 'addr');
  const exists = await sb
    .from('addresses')
    .select('id')
    .eq('customer_id', customerId)
    .eq('id', id)
    .maybeSingle();
  if (exists.error) throw dbError(exists.error, 'address.exists');
  if (exists.data) return { error: 'Address already exists', code: 409 };
  const { data: row, error } = await sb
    .from('addresses')
    .insert({ id, customer_id: customerId, ...normalize(data) })
    .select('*')
    .single();
  if (error) throw dbError(error, 'address.create');
  const def = await _defaultId(sb, customerId);
  if (!def) {
    await sb
      .from('customers')
      .update({ default_address_id: id, updated_at: new Date().toISOString() })
      .eq('customer_id', customerId);
  }
  return { address: fromRow(row) };
}

async function update(customerId, id, data = {}) {
  const sb = getSupabase();
  if (!sb) {
    const b = book(customerId);
    const prev = b.items.get(id);
    if (!prev) return { error: 'Address not found', code: 404 };
    const next = { id, ...normalize({ ...prev, ...data }) };
    b.items.set(id, next);
    return { address: next };
  }
  const { data: row, error } = await sb
    .from('addresses')
    .update(normalize(data))
    .eq('customer_id', customerId)
    .eq('id', id)
    .select('*')
    .maybeSingle();
  if (error) throw dbError(error, 'address.update');
  if (!row) return { error: 'Address not found', code: 404 };
  return { address: fromRow(row) };
}

async function select(customerId, id) {
  const sb = getSupabase();
  if (!sb) {
    const b = book(customerId);
    if (!b.items.has(id)) return { error: 'Address not found', code: 404 };
    b.defaultId = id;
    return { defaultId: id };
  }
  const { data, error } = await sb
    .from('addresses')
    .select('id')
    .eq('customer_id', customerId)
    .eq('id', id)
    .maybeSingle();
  if (error) throw dbError(error, 'address.select');
  if (!data) return { error: 'Address not found', code: 404 };
  const { error: upErr } = await sb
    .from('customers')
    .update({ default_address_id: id, updated_at: new Date().toISOString() })
    .eq('customer_id', customerId);
  if (upErr) throw dbError(upErr, 'address.select.set');
  return { defaultId: id };
}

async function remove(customerId, id) {
  const sb = getSupabase();
  if (!sb) {
    const b = book(customerId);
    if (!b.items.has(id)) return { error: 'Address not found', code: 404 };
    b.items.delete(id);
    if (b.defaultId === id) {
      b.defaultId = b.items.size ? b.items.keys().next().value : null;
    }
    return { removed: id, defaultId: b.defaultId };
  }
  const { data, error } = await sb
    .from('addresses')
    .delete()
    .eq('customer_id', customerId)
    .eq('id', id)
    .select('id')
    .maybeSingle();
  if (error) throw dbError(error, 'address.remove');
  if (!data) return { error: 'Address not found', code: 404 };
  const { data: rest, error: listErr } = await sb
    .from('addresses')
    .select('id')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: true })
    .limit(1);
  if (listErr) throw dbError(listErr, 'address.remove.remain');
  const nextDefault = rest && rest.length ? rest[0].id : null;
  await sb
    .from('customers')
    .update({ default_address_id: nextDefault, updated_at: new Date().toISOString() })
    .eq('customer_id', customerId);
  return { removed: id, defaultId: nextDefault };
}

function resetForTests() {
  books.clear();
}

module.exports = { list, create, update, select, remove, resetForTests };
