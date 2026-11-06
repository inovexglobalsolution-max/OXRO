'use strict';

const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const MAX = 8;
const recents = new Map(); // customerId -> [query] newest-first (fallback)

function sortRows(rows) {
  return rows
    .slice()
    .sort((a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')))
    .map((r) => r.query);
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) return recents.get(customerId) || [];
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('search_recents')
    .select('query, created_at')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: false })
    .limit(MAX);
  if (error) throw dbError(error, 'recents.list');
  return sortRows(data || []);
}

async function push(customerId, query) {
  const q = String(query || '').trim();
  if (!q) return list(customerId);
  const sb = getSupabase();
  if (!sb) {
    let arr = recents.get(customerId) || [];
    arr = arr.filter((x) => x.toLowerCase() !== q.toLowerCase());
    arr.unshift(q);
    if (arr.length > MAX) arr = arr.slice(0, MAX);
    recents.set(customerId, arr);
    return arr;
  }
  await ensureCustomer(customerId);
  const { error } = await sb.from('search_recents').upsert(
    { customer_id: customerId, query: q, created_at: new Date().toISOString() },
    { onConflict: 'customer_id,query' },
  );
  if (error) throw dbError(error, 'recents.push');
  // Enforce the cap after insert.
  const all = await list(customerId);
  if (all.length > MAX) {
    await sb
      .from('search_recents')
      .delete()
      .eq('customer_id', customerId)
      .in('query', all.slice(MAX));
    return all.slice(0, MAX);
  }
  return all;
}

async function remove(customerId, query) {
  const sb = getSupabase();
  if (!sb) {
    if (!query) {
      recents.delete(customerId);
      return [];
    }
    const arr = (recents.get(customerId) || []).filter(
      (x) => x.toLowerCase() !== String(query).toLowerCase(),
    );
    recents.set(customerId, arr);
    return arr;
  }
  if (query) {
    const { error } = await sb
      .from('search_recents')
      .delete()
      .eq('customer_id', customerId)
      .eq('query', String(query));
    if (error) throw dbError(error, 'recents.remove');
  } else {
    const { error } = await sb
      .from('search_recents')
      .delete()
      .eq('customer_id', customerId);
    if (error) throw dbError(error, 'recents.clear');
  }
  return list(customerId);
}

function resetForTests() {
  recents.clear();
}

module.exports = { list, push, remove, resetForTests };
