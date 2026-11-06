'use strict';

const { nowIso } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const carts = new Map(); // in-memory fallback

function cart(customerId) {
  let c = carts.get(customerId);
  if (!c) {
    c = {
      lines: new Map(),
      instructions: '',
      cutleryOptIn: false,
      restaurantId: null,
      restaurantName: null,
      updatedAt: nowIso(),
    };
    carts.set(customerId, c);
  }
  return c;
}

function lineKey(productId, size) {
  return size == null || size === '' ? `${productId}` : `${productId}__${size}`;
}

function view(c) {
  return {
    lines: [...c.lines.values()].map((l) => ({
      key: l.key,
      productId: l.productId,
      product: l.product,
      qty: l.qty,
      size: l.size,
      schedule: l.schedule,
    })),
    instructions: c.instructions,
    cutleryOptIn: c.cutleryOptIn,
    restaurantId: c.restaurantId,
    restaurantName: c.restaurantName,
    updatedAt: c.updatedAt,
  };
}

function refreshMeta(c) {
  for (const l of c.lines.values()) {
    const p = l.product || {};
    if (p.restaurantId) {
      c.restaurantId = p.restaurantId;
      c.restaurantName = p.restaurantName || null;
      return;
    }
  }
  c.restaurantId = null;
  c.restaurantName = null;
}

// ---------------------------------------------------------------- DB shape
function metaFromLines(lines) {
  for (const l of lines) {
    const p = (l.product && l.product.restaurantId) ? l.product : null;
    if (p) return { restaurantId: p.restaurantId, restaurantName: p.restaurantName || null };
  }
  return { restaurantId: null, restaurantName: null };
}

async function _read(sb, customerId) {
  const [{ data: meta, error: mErr }, { data: rows, error: lErr }] = await Promise.all([
    sb.from('carts').select('*').eq('customer_id', customerId).maybeSingle(),
    sb
      .from('cart_lines')
      .select('*')
      .eq('customer_id', customerId)
      .order('id', { ascending: true }),
  ]);
  if (mErr) throw dbError(mErr, 'cart.meta');
  if (lErr) throw dbError(lErr, 'cart.lines');
  const lines = (rows || []).map((r) => ({
    key: r.line_key,
    productId: r.product_id,
    product: r.product,
    qty: r.qty,
    size: r.size,
    schedule: r.schedule,
  }));
  return {
    lines,
    instructions: (meta && meta.instructions) || '',
    cutleryOptIn: !!(meta && meta.cutlery_opt_in),
    restaurantId: meta ? meta.restaurant_id : null,
    restaurantName: meta ? meta.restaurant_name : null,
    updatedAt: (meta && meta.updated_at) || nowIso(),
  };
}

function viewFromDb(c) {
  return {
    lines: c.lines.map((l) => ({
      key: l.key,
      productId: l.productId,
      product: l.product,
      qty: l.qty,
      size: l.size,
      schedule: l.schedule,
    })),
    instructions: c.instructions,
    cutleryOptIn: c.cutleryOptIn,
    restaurantId: c.restaurantId,
    restaurantName: c.restaurantName,
    updatedAt: c.updatedAt,
  };
}

async function _writeMeta(sb, customerId, c) {
  const { error } = await sb.from('carts').upsert(
    {
      customer_id: customerId,
      instructions: c.instructions,
      cutlery_opt_in: c.cutleryOptIn,
      restaurant_id: c.restaurantId,
      restaurant_name: c.restaurantName,
      updated_at: nowIso(),
    },
    { onConflict: 'customer_id' },
  );
  if (error) throw dbError(error, 'cart.saveMeta');
}

async function _writeLines(sb, customerId, lines) {
  const { error } = await sb.from('cart_lines').delete().eq('customer_id', customerId);
  if (error) throw dbError(error, 'cart.clearLines');
  if (!lines.length) return;
  const rows = lines.map((l) => ({
    customer_id: customerId,
    line_key: l.key,
    product_id: String(l.productId),
    product: l.product,
    qty: l.qty,
    size: l.size,
    schedule: l.schedule,
  }));
  const { error: insErr } = await sb.from('cart_lines').insert(rows);
  if (insErr) throw dbError(insErr, 'cart.insertLines');
}

// ---------------------------------------------------------------- API
async function upsertLine(customerId, data = {}) {
  const product = data.product;
  if (!product || product.id == null) {
    return { error: 'product with an id is required' };
  }
  const qty = Number(data.qty);
  if (!Number.isInteger(qty) || qty < 0) {
    return { error: 'qty must be a non-negative integer' };
  }
  const size = data.size == null || data.size === '' ? null : String(data.size);
  const key = lineKey(product.id, size);

  const sb = getSupabase();
  if (!sb) {
    const c = cart(customerId);
    if (qty === 0) {
      c.lines.delete(key);
    } else {
      c.lines.set(key, {
        key,
        productId: product.id,
        product,
        qty,
        size,
        schedule: data.schedule || null,
      });
    }
    c.updatedAt = nowIso();
    refreshMeta(c);
    return { cart: view(c), key };
  }

  await ensureCustomer(customerId);
  if (qty === 0) {
    await sb
      .from('cart_lines')
      .delete()
      .eq('customer_id', customerId)
      .eq('line_key', key);
  } else {
    const { error } = await sb.from('cart_lines').upsert(
      {
        customer_id: customerId,
        line_key: key,
        product_id: String(product.id),
        product,
        qty,
        size,
        schedule: data.schedule || null,
        updated_at: nowIso(),
      },
      { onConflict: 'customer_id,line_key' },
    );
    if (error) throw dbError(error, 'cart.upsertLine');
  }
  const c = await _read(sb, customerId);
  Object.assign(c, metaFromLines(c.lines));
  await _writeMeta(sb, customerId, c);
  return { cart: viewFromDb(c), key };
}

async function updateLine(customerId, key, data = {}) {
  const qty = Number(data.qty);
  if (!Number.isInteger(qty) || qty < 0) {
    return { error: 'qty must be a non-negative integer' };
  }
  const sb = getSupabase();
  if (!sb) {
    const c = cart(customerId);
    const line = c.lines.get(key);
    if (!line) return { error: 'Cart line not found', code: 404 };
    if (qty === 0) {
      c.lines.delete(key);
    } else {
      line.qty = qty;
      if (data.schedule !== undefined) line.schedule = data.schedule;
    }
    c.updatedAt = nowIso();
    refreshMeta(c);
    return { cart: view(c) };
  }

  await ensureCustomer(customerId);
  if (qty === 0) {
    const { data: del, error } = await sb
      .from('cart_lines')
      .delete()
      .eq('customer_id', customerId)
      .eq('line_key', key)
      .select('line_key')
      .maybeSingle();
    if (error) throw dbError(error, 'cart.updateLine.del');
    if (!del) return { error: 'Cart line not found', code: 404 };
  } else {
    const patch = { qty, updated_at: nowIso() };
    if (data.schedule !== undefined) patch.schedule = data.schedule;
    const { data: row, error } = await sb
      .from('cart_lines')
      .update(patch)
      .eq('customer_id', customerId)
      .eq('line_key', key)
      .select('line_key')
      .maybeSingle();
    if (error) throw dbError(error, 'cart.updateLine');
    if (!row) return { error: 'Cart line not found', code: 404 };
  }
  const c = await _read(sb, customerId);
  Object.assign(c, metaFromLines(c.lines));
  await _writeMeta(sb, customerId, c);
  return { cart: viewFromDb(c) };
}

async function get(customerId) {
  const sb = getSupabase();
  if (!sb) return view(cart(customerId));
  await ensureCustomer(customerId);
  const c = await _read(sb, customerId);
  return viewFromDb(c);
}

/**
 * Replace the whole cart (client sync snapshot). Lines without a valid
 * product id are skipped so a malformed payload cannot poison the cart.
 */
async function replace(customerId, data = {}) {
  const clean = [];
  for (const raw of Array.isArray(data.lines) ? data.lines : []) {
    const product = raw && raw.product;
    const qty = Number(raw && raw.qty);
    if (!product || product.id == null || !Number.isInteger(qty) || qty <= 0) {
      continue;
    }
    const size = raw.size == null || raw.size === '' ? null : String(raw.size);
    clean.push({
      key: lineKey(product.id, size),
      productId: product.id,
      product,
      qty,
      size,
      schedule: raw.schedule || null,
    });
  }
  const instructions = String(data.instructions || '').slice(0, 140);
  const cutleryOptIn = !!data.cutleryOptIn;

  const sb = getSupabase();
  if (!sb) {
    const c = cart(customerId);
    c.lines.clear();
    for (const l of clean) c.lines.set(l.key, l);
    c.instructions = instructions;
    c.cutleryOptIn = cutleryOptIn;
    c.updatedAt = nowIso();
    refreshMeta(c);
    return { cart: view(c) };
  }

  await ensureCustomer(customerId);
  await _writeLines(sb, customerId, clean);
  const meta = metaFromLines(clean);
  await _writeMeta(sb, customerId, {
    instructions,
    cutleryOptIn,
    ...meta,
  });
  return {
    cart: viewFromDb({
      lines: clean,
      instructions,
      cutleryOptIn,
      ...meta,
      updatedAt: nowIso(),
    }),
  };
}

async function removeLine(customerId, key) {
  const sb = getSupabase();
  if (!sb) {
    const c = cart(customerId);
    if (!c.lines.delete(key)) return { error: 'Cart line not found', code: 404 };
    c.updatedAt = nowIso();
    refreshMeta(c);
    return { cart: view(c) };
  }
  const { data, error } = await sb
    .from('cart_lines')
    .delete()
    .eq('customer_id', customerId)
    .eq('line_key', key)
    .select('line_key')
    .maybeSingle();
  if (error) throw dbError(error, 'cart.removeLine');
  if (!data) return { error: 'Cart line not found', code: 404 };
  const c = await _read(sb, customerId);
  Object.assign(c, metaFromLines(c.lines));
  await _writeMeta(sb, customerId, c);
  return { cart: viewFromDb(c) };
}

async function clear(customerId) {
  const sb = getSupabase();
  if (!sb) {
    const c = cart(customerId);
    c.lines.clear();
    c.instructions = '';
    c.cutleryOptIn = false;
    c.restaurantId = null;
    c.restaurantName = null;
    c.updatedAt = nowIso();
    return { cart: view(c) };
  }
  await ensureCustomer(customerId);
  const { error } = await sb.from('cart_lines').delete().eq('customer_id', customerId);
  if (error) throw dbError(error, 'cart.clear');
  await _writeMeta(sb, customerId, {
    instructions: '',
    cutleryOptIn: false,
    restaurantId: null,
    restaurantName: null,
  });
  return {
    cart: {
      lines: [],
      instructions: '',
      cutleryOptIn: false,
      restaurantId: null,
      restaurantName: null,
      updatedAt: nowIso(),
    },
  };
}

function resetForTests() {
  carts.clear();
}

module.exports = {
  get,
  upsertLine,
  updateLine,
  replace,
  removeLine,
  clear,
  lineKey,
  resetForTests,
};
