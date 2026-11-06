'use strict';

const { getSupabase, dbError } = require('../db/helpers');

const INITIAL = {
  version: 1,
  effectiveFromIso: '2026-01-01T00:00:00Z',
  commissionBps: 500,
  platformFeePaise: 700,
  customerDeliveryFeePaise: 4000,
  customerPackagingFeePaise: 0,
  customerGstBps: 500,
  commissionGstBps: 1800,
  tdsBps: 100,
  basePayoutPaise: 2500,
  includedDistanceMetres: 3000,
  perKmPaise: 700,
  stackingBonusPaise: 0,
  freeWaitingMinutes: 5,
  waitingCompPerMinutePaise: 0,
  peakWindows: [],
  specialIncentives: [],
};

let config = { ...INITIAL }; // in-memory fallback

const NUMERIC_FIELDS = Object.keys(INITIAL).filter(
  (k) => typeof INITIAL[k] === 'number' && k !== 'version',
);

async function get() {
  const sb = getSupabase();
  if (!sb) return { ...config, peakWindows: [...config.peakWindows] };
  const { data, error } = await sb
    .from('pricing_config')
    .select('config')
    .eq('id', 1)
    .maybeSingle();
  if (error) throw dbError(error, 'pricing.get');
  if (!data) return { ...INITIAL, peakWindows: [], specialIncentives: [] };
  return data.config;
}

function validate(patch) {
  for (const key of NUMERIC_FIELDS) {
    if (patch[key] === undefined) continue;
    const v = Number(patch[key]);
    if (!Number.isInteger(v) || v < 0) {
      return { error: `${key} must be a non-negative integer` };
    }
  }
  if (patch.commissionBps !== undefined && Number(patch.commissionBps) > 10000) {
    return { error: 'commissionBps must be <= 10000' };
  }
  return null;
}

function merge(current, patch) {
  const next = { ...current };
  for (const key of NUMERIC_FIELDS) {
    if (patch[key] !== undefined) next[key] = Number(patch[key]);
  }
  if (Array.isArray(patch.peakWindows)) next.peakWindows = patch.peakWindows;
  if (Array.isArray(patch.specialIncentives)) {
    next.specialIncentives = patch.specialIncentives;
  }
  next.version = current.version + 1;
  return next;
}

/**
 * Applies a validated admin patch and bumps the version so every later
 * order snapshots the new rates.
 */
async function update(patch = {}) {
  const err = validate(patch);
  if (err) return err;

  const sb = getSupabase();
  if (!sb) {
    const next = merge(config, patch);
    config = next;
    return { config: { ...config, peakWindows: [...config.peakWindows] } };
  }

  const { data: row, error: rErr } = await sb
    .from('pricing_config')
    .select('config')
    .eq('id', 1)
    .maybeSingle();
  if (rErr) throw dbError(rErr, 'pricing.update.read');
  const current = row ? row.config : { ...INITIAL, peakWindows: [], specialIncentives: [] };
  const next = merge(current, patch);
  const { error } = await sb
    .from('pricing_config')
    .upsert({ id: 1, config: next, updated_at: new Date().toISOString() }, {
      onConflict: 'id',
    });
  if (error) throw dbError(error, 'pricing.update');
  const { error: aErr } = await sb
    .from('pricing_audit')
    .insert({ version: next.version, summary: 'Pricing updated' });
  if (aErr) throw dbError(aErr, 'pricing.audit');
  return { config: next };
}

function resetForTests() {
  config = { ...INITIAL, peakWindows: [], specialIncentives: [] };
}

module.exports = { get, update, resetForTests, INITIAL };
