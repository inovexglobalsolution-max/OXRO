'use strict';

const { getSupabase } = require('../config/supabase');

/** Throws a plain Error so Express 5 forwards it to errorHandler. */
function dbError(error, context) {
  const msg = (error && error.message) || 'Database error';
  const err = new Error(`${context}: ${msg}`);
  err.status = 500;
  return err;
}

/**
 * Every FK targets customers(customer_id) — upsert the row first so any
 * write path (even before /profile/me) satisfies the constraint.
 */
async function ensureCustomer(customerId) {
  const sb = getSupabase();
  if (!sb) return;
  const { error } = await sb
    .from('customers')
    .upsert({ customer_id: customerId }, { onConflict: 'customer_id', ignoreDuplicates: true });
  if (error) throw dbError(error, 'ensureCustomer');
}

/** Maps a DB row to the API camelCase shape (undefined-safe). */
function mapRow(row, keys) {
  const out = {};
  for (const [outKey, col] of Object.entries(keys)) out[outKey] = row[col];
  return out;
}

module.exports = { getSupabase, dbError, ensureCustomer, mapRow };
