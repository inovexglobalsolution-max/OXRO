'use strict';
// End-to-end smoke: backend HTTP API -> Supabase rows (read back via Management API).
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const BASE = 'http://localhost:5000';
const CID = 'smoke-customer-1';
const token = process.env.SUPABASE_ACCESS_TOKEN;
const ref = 'rmsrzsceuvbykcvoapet';

let pass = 0;
let fail = 0;

function ok(name, cond, extra) {
  if (cond) {
    pass++;
    console.log(`  PASS ${name}`);
  } else {
    fail++;
    console.log(`  FAIL ${name}${extra ? ' :: ' + extra : ''}`);
  }
}

async function api(method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function db(query) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(j).slice(0, 400));
  return j;
}

async function main() {
  console.log('== 1. profile ==');
  const p = await api('PUT', '/profile/me', {
    customerId: CID, name: 'Smoke User', email: 'smoke@oxro.dev', phone: '9876543210',
  });
  ok('PUT /profile/me 200', p.status === 200 && p.data.profile?.name === 'Smoke User');
  let rows = await db(`select name, email from customers where customer_id='${CID}'`);
  ok('customers row in Supabase', rows.length === 1 && rows[0].name === 'Smoke User', JSON.stringify(rows));

  console.log('== 2. address ==');
  const a = await api('POST', '/addresses', {
    customerId: CID, id: 'smoke_home', label: 'Home', name: 'Smoke User',
    phone: '9876543210', line: '12 MG Road', city: 'Chennai', pin: '600001',
  });
  ok('POST /addresses 201', a.status === 201);
  rows = await db(`select id, pin from addresses where customer_id='${CID}'`);
  ok('addresses row in Supabase', rows.length === 1 && rows[0].pin === '600001');

  console.log('== 3. cart ==');
  const product = {
    id: 900001, name: 'Hyderabadi Chicken Biryani', brand: 'Paradise Biryani',
    price: 249, mrp: 299, rating: 4.5, reviews: 980, icon: 58732,
    colors: [4294967295, 4294928896], restaurantId: 'r_paradise',
    restaurantName: 'Paradise Biryani', veg: false, egg: false, description: '', imageUrl: null,
  };
  const c = await api('PUT', '/cart', {
    customerId: CID, lines: [{ product, qty: 2 }], instructions: 'Extra spicy', cutleryOptIn: true,
  });
  ok('PUT /cart 200', c.status === 200 && c.data.lines?.length === 1);
  rows = await db(`select qty from cart_lines where customer_id='${CID}'`);
  ok('cart_lines row in Supabase', rows.length === 1 && rows[0].qty === 2);

  console.log('== 4. pricing from DB ==');
  const pr = await api('GET', '/pricing');
  ok('GET /pricing from DB', pr.status === 200 && pr.data.config?.platformFeePaise === 700 && pr.data.config?.version === 1);

  console.log('== 5. checkout place ==');
  const bill = {
    itemSubtotalPaise: 49800, packagingPaise: 0, deliveryPaise: 4000,
    platformFeePaise: 700, smallCartFeePaise: 0, taxPaise: 2490,
    tipPaise: 0, discountPaise: 0,
    grandTotalPaise: 49800 + 4000 + 700 + 2490, configVersion: 1,
  };
  const o = await api('POST', '/checkout/place', {
    customerId: CID, orderId: 'OXROSMOKE1', products: [{ ...product }, { ...product }],
    restaurantId: 'r_paradise', restaurantName: 'Paradise Biryani',
    instructions: 'Extra spicy', cutleryOptIn: true, paymentMethod: 'cod', bill,
  });
  ok('POST /checkout/place 201', o.status === 201 && o.data.order?.id === 'OXROSMOKE1',
     JSON.stringify(o.data).slice(0, 200));
  rows = await db(`select status, payment_method, bill->>'grandTotalPaise' as gt from orders where id='OXROSMOKE1'`);
  ok('orders row in Supabase', rows.length === 1 && rows[0].status === 'processing' && rows[0].gt === '56990');
  rows = await db(`select count(*) as n from cart_lines where customer_id='${CID}'`);
  ok('cart cleared after order', Number(rows[0].n) === 0);

  console.log('== 6. orders list read-back ==');
  const ol = await api('GET', `/orders?customerId=${CID}`);
  ok('GET /orders returns placed order', ol.data.orders?.some((x) => x.id === 'OXROSMOKE1'));

  console.log('== 7. smart change ==');
  const sc = await api('POST', '/smart-change/activate', {
    customerId: CID, orderAmountPaise: 32000, cashAmountPaise: 50000, idempotencyKey: 'smoke-idem-1',
  });
  ok('activate 201', sc.status === 201 && sc.data.remainingChangePaise === 18000);
  await api('POST', `/smart-change/${sc.data.txnId}/link-order`, { orderId: 'OXROSMOKE2' });
  const coll = await api('POST', `/smart-change/${sc.data.txnId}/collect`, {
    partnerId: 'partner-rider', actualCashPaise: 50000,
  });
  ok('collect credits wallet', coll.status === 200 && coll.data.transactionStatus === 'credited');
  rows = await db(`select balance_paise from wallets where customer_id='${CID}'`);
  ok('wallets row = 18000 paise', rows.length === 1 && rows[0].balance_paise === 18000, JSON.stringify(rows));
  rows = await db(`select transaction_status from smart_change_transactions where txn_id='${sc.data.txnId}'`);
  ok('smart_change row credited', rows[0]?.transaction_status === 'credited');

  console.log('== 8. search + restaurants from DB ==');
  const s = await api('GET', '/search?q=biryani');
  ok('search hits seeded dishes', s.status === 200 && s.data.results?.length > 0);
  const rl = await api('GET', '/restaurants');
  ok('restaurants from DB', rl.data.restaurants?.length === 7);
  const cu = await api('GET', '/coupons');
  ok('coupons from DB', cu.data.coupons?.length === 4);

  console.log('== 9. new endpoints ==');
  const w = await api('POST', '/wishlist', { customerId: CID, product });
  ok('wishlist add', w.status === 200 && w.data.items?.length === 1);
  const rv = await api('POST', '/reviews', { customerId: CID, productId: 900001, rating: 5, body: 'Great' });
  ok('review upsert 201', rv.status === 201);
  const st = await api('POST', '/support/tickets', {
    customerId: CID, source: 'order', categoryId: 'missing', categoryLabel: 'Missing item', orderId: 'OXROSMOKE1',
  });
  ok('support ticket 201', st.status === 201);
  const nt = await api('POST', '/notifications', { customerId: CID, title: 'Order placed!', sub: 'ok', kind: 'order', icon: 57468, time: 'now' });
  ok('notification 201', nt.status === 201);
  const pj = await api('POST', '/profile/premium/join', { customerId: CID });
  ok('premium join', pj.data.isMember === true);
  const pf = await api('PUT', '/profile/preferences', { customerId: CID, enabled: true, preference: 'veg' });
  ok('preferences save', pf.data.preference === 'veg');
  await api('POST', '/search/recents', { customerId: CID, query: 'Biryani' });
  const rc = await api('GET', `/search/recents?customerId=${CID}`);
  ok('recents push+list', rc.data.queries?.includes('Biryani'));
  const dbk = await api('POST', '/dineout/bookings', { customerId: CID, restaurantId: 'd_verandah', guests: 4, slot: '8:00 PM' });
  ok('dineout booking 201', dbk.status === 201);

  rows = await db(`select
    (select count(*) from wishlists) as wl,
    (select count(*) from reviews) as rv,
    (select count(*) from support_tickets) as st,
    (select count(*) from notifications) as nt,
    (select premium_member from customers where customer_id='${CID}') as pm,
    (select count(*) from search_recents) as sr,
    (select count(*) from dineout_bookings) as dbk`);
  const r0 = rows[0];
  ok('all new rows landed in Supabase',
     r0.wl >= 1 && r0.rv >= 1 && r0.st >= 1 && r0.nt >= 1 && r0.pm === true && r0.sr >= 1 && r0.dbk >= 1,
     JSON.stringify(r0));

  console.log(`\nRESULT: ${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
}

main().catch((e) => {
  console.error('SMOKE ERROR:', e.message);
  process.exit(1);
});
