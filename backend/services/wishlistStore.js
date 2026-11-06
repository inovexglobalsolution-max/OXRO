'use strict';

const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const items = new Map(); // customerId -> Map<productId, product> (fallback)

function listFor(customerId) {
  const m = items.get(customerId);
  return m ? [...m.values()] : [];
}

function fromRow(r) {
  return r.product;
}

async function list(customerId) {
  const sb = getSupabase();
  if (!sb) return listFor(customerId);
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('wishlists')
    .select('product')
    .eq('customer_id', customerId)
    .order('created_at', { ascending: true });
  if (error) throw dbError(error, 'wishlist.list');
  return (data || []).map(fromRow);
}

async function add(customerId, product) {
  const sb = getSupabase();
  if (!sb) {
    let m = items.get(customerId);
    if (!m) {
      m = new Map();
      items.set(customerId, m);
    }
    if (!m.has(product.id)) m.set(product.id, product);
    return listFor(customerId);
  }
  await ensureCustomer(customerId);
  const { error } = await sb.from('wishlists').upsert(
    { customer_id: customerId, product_id: product.id, product },
    { onConflict: 'customer_id,product_id', ignoreDuplicates: true },
  );
  if (error) throw dbError(error, 'wishlist.add');
  return list(customerId);
}

async function remove(customerId, productId) {
  const sb = getSupabase();
  if (!sb) {
    const m = items.get(customerId);
    if (m) m.delete(productId);
    return listFor(customerId);
  }
  const { error } = await sb
    .from('wishlists')
    .delete()
    .eq('customer_id', customerId)
    .eq('product_id', productId);
  if (error) throw dbError(error, 'wishlist.remove');
  return list(customerId);
}

function resetForTests() {
  items.clear();
}

module.exports = { list, add, remove, resetForTests };
