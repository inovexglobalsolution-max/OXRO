'use strict';

const { createClient } = require('@supabase/supabase-js');

let _client;
let _checked = false;

function _looksReal(value) {
  return typeof value === 'string' && value.length > 8 && !value.includes('<paste');
}

/**
 * Supabase client for the backend only (service-role / secret key).
 * Returns null until real credentials are filled in `.env`, so every
 * caller falls back to the in-memory store. Never call from Flutter.
 */
function getSupabase() {
  if (_checked) return _client;
  _checked = true;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!_looksReal(url) || !_looksReal(key)) {
    _client = null;
    return _client;
  }
  _client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return _client;
}

function supabaseEnabled() {
  return getSupabase() !== null;
}

/** Test hook: force a fresh lookup after env changes. */
function resetSupabaseClient() {
  _client = undefined;
  _checked = false;
}

module.exports = { getSupabase, supabaseEnabled, resetSupabaseClient };
