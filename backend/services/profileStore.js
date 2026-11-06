'use strict';

const { nowIso } = require('../utils/ids');
const { getSupabase, dbError, ensureCustomer } = require('../db/helpers');

const profiles = new Map(); // in-memory fallback (tests / no credentials)

const COLUMNS = 'customer_id, name, email, phone, created_at, updated_at';

function fromRow(r) {
  if (!r) return null;
  return {
    customerId: r.customer_id,
    name: r.name || '',
    email: r.email || '',
    phone: r.phone || '',
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

async function get(customerId) {
  const sb = getSupabase();
  if (!sb) return profiles.get(customerId) || null;
  const { data, error } = await sb
    .from('customers')
    .select(COLUMNS)
    .eq('customer_id', customerId)
    .maybeSingle();
  if (error) throw dbError(error, 'profile.get');
  return fromRow(data);
}

async function upsert(customerId, data = {}) {
  const sb = getSupabase();
  if (!sb) {
    const prev = profiles.get(customerId) || {
      customerId,
      name: '',
      email: '',
      phone: '',
      createdAt: nowIso(),
    };
    const next = {
      ...prev,
      name: data.name === undefined ? prev.name : String(data.name).trim(),
      email: data.email === undefined ? prev.email : String(data.email).trim(),
      phone: data.phone === undefined ? prev.phone : String(data.phone).trim(),
      updatedAt: nowIso(),
    };
    profiles.set(customerId, next);
    return next;
  }
  const patch = { customer_id: customerId, updated_at: nowIso() };
  if (data.name !== undefined) patch.name = String(data.name).trim();
  if (data.email !== undefined) patch.email = String(data.email).trim();
  if (data.phone !== undefined) patch.phone = String(data.phone).trim();
  const { data: row, error } = await sb
    .from('customers')
    .upsert(patch, { onConflict: 'customer_id' })
    .select(COLUMNS)
    .single();
  if (error) throw dbError(error, 'profile.upsert');
  return fromRow(row);
}

function resetForTests() {
  profiles.clear();
}

// ------------------------------------------------------------ premium
async function getPremium(customerId) {
  const sb = getSupabase();
  if (!sb) {
    const p = profiles.get(customerId);
    return {
      isMember: !!(p && p.premiumMember),
      joinedAt: (p && p.premiumJoinedAt) || null,
    };
  }
  const { data, error } = await sb
    .from('customers')
    .select('premium_member, premium_joined_at')
    .eq('customer_id', customerId)
    .maybeSingle();
  if (error) throw dbError(error, 'premium.get');
  return {
    isMember: !!(data && data.premium_member),
    joinedAt: data ? data.premium_joined_at : null,
  };
}

async function joinPremium(customerId) {
  const current = await getPremium(customerId);
  if (current.isMember) return current;
  const joinedAt = nowIso();
  const sb = getSupabase();
  if (!sb) {
    const p = profiles.get(customerId) || {
      customerId,
      name: '',
      email: '',
      phone: '',
      createdAt: joinedAt,
    };
    p.premiumMember = true;
    p.premiumJoinedAt = joinedAt;
    profiles.set(customerId, p);
    return { isMember: true, joinedAt };
  }
  await ensureCustomer(customerId);
  const { data, error } = await sb
    .from('customers')
    .update({ premium_member: true, premium_joined_at: joinedAt, updated_at: joinedAt })
    .eq('customer_id', customerId)
    .select('premium_member, premium_joined_at')
    .single();
  if (error) throw dbError(error, 'premium.join');
  return { isMember: !!data.premium_member, joinedAt: data.premium_joined_at };
}

async function cancelPremium(customerId) {
  const sb = getSupabase();
  if (!sb) {
    const p = profiles.get(customerId);
    if (p) {
      p.premiumMember = false;
      p.premiumJoinedAt = null;
    }
    return { isMember: false, joinedAt: null };
  }
  const { error } = await sb
    .from('customers')
    .update({ premium_member: false, premium_joined_at: null, updated_at: nowIso() })
    .eq('customer_id', customerId);
  if (error) throw dbError(error, 'premium.cancel');
  return { isMember: false, joinedAt: null };
}

// ------------------------------------------------------- food preferences
async function getPreferences(customerId) {
  const sb = getSupabase();
  if (!sb) {
    const p = profiles.get(customerId);
    return {
      enabled: !!(p && p.foodPreferenceEnabled),
      preference: (p && p.foodPreference) || null,
    };
  }
  const { data, error } = await sb
    .from('customers')
    .select('food_preference_enabled, food_preference')
    .eq('customer_id', customerId)
    .maybeSingle();
  if (error) throw dbError(error, 'preferences.get');
  return {
    enabled: !!(data && data.food_preference_enabled),
    preference: data ? data.food_preference : null,
  };
}

async function setPreferences(customerId, data = {}) {
  const enabled = !!data.enabled;
  const preference = data.preference == null ? null : String(data.preference);
  const sb = getSupabase();
  if (!sb) {
    const p = profiles.get(customerId) || {
      customerId,
      name: '',
      email: '',
      phone: '',
      createdAt: nowIso(),
    };
    p.foodPreferenceEnabled = enabled;
    p.foodPreference = preference;
    profiles.set(customerId, p);
    return { enabled, preference };
  }
  await ensureCustomer(customerId);
  const { error } = await sb
    .from('customers')
    .update({
      food_preference_enabled: enabled,
      food_preference: preference,
      updated_at: nowIso(),
    })
    .eq('customer_id', customerId);
  if (error) throw dbError(error, 'preferences.set');
  return { enabled, preference };
}

module.exports = {
  get,
  upsert,
  getPremium,
  joinPremium,
  cancelPremium,
  getPreferences,
  setPreferences,
  resetForTests,
};
