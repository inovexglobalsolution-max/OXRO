'use strict';

const { getSupabase, dbError } = require('../db/helpers');

// Fallback mirrors the app's original coupon list (used by tests / no creds).
const FALLBACK = [
  { code: 'OXRO500', title: 'Flat Rs.500 OFF', sub: 'On orders above Rs.2,999', off: 500, percent: false, cap: 0, minOrder: 2999, freeShip: false },
  { code: 'WELCOME10', title: '10% OFF up to Rs.300', sub: 'On orders above Rs.999', off: 10, percent: true, cap: 300, minOrder: 999, freeShip: false },
  { code: 'FEST200', title: 'Flat Rs.200 OFF', sub: 'On orders above Rs.1,499', off: 200, percent: false, cap: 0, minOrder: 1499, freeShip: false },
  { code: 'FREESHIP', title: 'Free Delivery', sub: 'No shipping fee above Rs.499', off: 0, percent: false, cap: 0, minOrder: 499, freeShip: true },
];

function fromRow(r) {
  return {
    code: r.code,
    title: r.title,
    sub: r.sub,
    off: r.off,
    percent: r.percent,
    cap: r.cap,
    minOrder: r.min_order,
    freeShip: r.free_ship,
  };
}

async function list() {
  const sb = getSupabase();
  if (!sb) return FALLBACK.map((c) => ({ ...c }));
  const { data, error } = await sb
    .from('coupons')
    .select('*')
    .eq('active', true)
    .order('code', { ascending: true });
  if (error) throw dbError(error, 'coupons.list');
  return (data || []).map(fromRow);
}

module.exports = { list };
