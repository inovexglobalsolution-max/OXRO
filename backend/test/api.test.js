'use strict';

// Tests always run against the in-memory store, even when real Supabase
// credentials exist in .env (dotenv will not override these empty values).
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const profileStore = require('../services/profileStore');
const addressStore = require('../services/addressStore');
const cartStore = require('../services/cartStore');
const walletStore = require('../services/walletStore');
const pricingStore = require('../services/pricingStore');
const orderStore = require('../services/orderStore');
const smartChangeStore = require('../services/smartChangeStore');
const wishlistStore = require('../services/wishlistStore');
const reviewStore = require('../services/reviewStore');
const supportStore = require('../services/supportStore');
const notificationStore = require('../services/notificationStore');
const searchHistoryStore = require('../services/searchHistoryStore');
const dineoutStore = require('../services/dineoutStore');

let server;
let base;

before(async () => {
  const app = require('../index');
  server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => {
  profileStore.resetForTests();
  addressStore.resetForTests();
  cartStore.resetForTests();
  walletStore.resetForTests();
  pricingStore.resetForTests();
  orderStore.resetForTests();
  smartChangeStore.resetForTests();
  wishlistStore.resetForTests();
  reviewStore.resetForTests();
  supportStore.resetForTests();
  notificationStore.resetForTests();
  searchHistoryStore.resetForTests();
  dineoutStore.resetForTests();
});

async function call(method, path, body) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

const get = (path) => call('GET', path);
const post = (path, body) => call('POST', path, body);
const put = (path, body) => call('PUT', path, body);
const del = (path) => call('DELETE', path);

function bps(paise, rate) {
  return Math.floor((paise * rate + 5000) / 10000);
}

function billFor(itemSubtotalPaise, overrides = {}) {
  const packagingPaise = 0;
  const deliveryPaise = itemSubtotalPaise > 19900 ? 0 : 4000;
  const platformFeePaise = 700;
  const smallCartFeePaise = itemSubtotalPaise < 9900 ? 1000 : 0;
  const taxPaise = 0;
  const tipPaise = 0;
  const discountPaise = 0;
  const bill = {
    itemSubtotalPaise,
    packagingPaise,
    deliveryPaise,
    platformFeePaise,
    smallCartFeePaise,
    taxPaise,
    tipPaise,
    discountPaise,
    grandTotalPaise:
      itemSubtotalPaise +
      packagingPaise +
      deliveryPaise +
      platformFeePaise +
      smallCartFeePaise +
      taxPaise +
      tipPaise -
      discountPaise,
    ...overrides,
  };
  if (!('grandTotalPaise' in overrides)) {
    bill.grandTotalPaise =
      bill.itemSubtotalPaise +
      bill.packagingPaise +
      bill.deliveryPaise +
      bill.platformFeePaise +
      bill.smallCartFeePaise +
      bill.taxPaise +
      bill.tipPaise -
      bill.discountPaise;
  }
  return bill;
}

const product = {
  id: 901,
  name: 'Checkout Shirt',
  brand: 'OXRO',
  price: 799,
  mrp: 999,
  rating: 4.2,
  reviews: 100,
  icon: 0xe3a4,
  colors: [0xffffffff, 0xff000000],
  restaurantId: 'R-CHECKOUT',
  restaurantName: 'Checkout Kitchen',
};

test('health responds ok', async () => {
  const { status, data } = await get('/health');
  assert.equal(status, 200);
  assert.equal(data.status, 'ok');
});

test('profile: empty then upsert + read', async () => {
  const empty = await get('/profile/me?customerId=cust-1');
  assert.equal(empty.status, 200);
  assert.equal(empty.data.profile, null);

  const saved = await put('/profile/me', {
    customerId: 'cust-1',
    name: 'Sachin V',
    email: 'sachin@example.com',
    phone: '9876543210',
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.data.profile.name, 'Sachin V');

  const read = await get('/profile/me?customerId=cust-1');
  assert.equal(read.data.profile.email, 'sachin@example.com');
});

test('addresses: CRUD + default selection', async () => {
  const created = await post('/addresses', {
    customerId: 'cust-1',
    id: 'home1',
    label: 'Home',
    name: 'Sachin V',
    phone: '9876543210',
    line: '123, Anna Nagar',
    city: 'Chennai',
    pin: '600040',
  });
  assert.equal(created.status, 201);
  assert.equal(created.data.address.id, 'home1');

  await post('/addresses', {
    customerId: 'cust-1',
    id: 'office1',
    label: 'Office',
    name: 'Sachin V',
    phone: '9876543210',
    line: '45, Guindy',
    city: 'Chennai',
    pin: '600032',
  });

  const list = await get('/addresses?customerId=cust-1');
  assert.equal(list.data.addresses.length, 2);

  const selected = await post('/addresses/home1/select', { customerId: 'cust-1' });
  assert.equal(selected.data.defaultId, 'home1');

  const updated = await put('/addresses/home1', {
    customerId: 'cust-1',
    label: 'Home',
    name: 'Sachin V',
    phone: '9876543210',
    line: '123, Anna Nagar Main',
    city: 'Chennai',
    pin: '600040',
  });
  assert.equal(updated.data.address.line, '123, Anna Nagar Main');

  const removed = await del('/addresses/home1?customerId=cust-1');
  assert.equal(removed.data.removed, 'home1');
  const after = await get('/addresses?customerId=cust-1');
  assert.equal(after.data.addresses.length, 1);
  assert.equal(after.data.defaultId, 'office1');
});

test('cart: replace, item qty, remove and clear', async () => {
  const replaced = await put('/cart', {
    customerId: 'cust-1',
    instructions: 'Less spicy',
    cutleryOptIn: true,
    lines: [
      { product, qty: 2, size: 'M' },
      { product, qty: 1 },
    ],
  });
  assert.equal(replaced.status, 200);
  assert.equal(replaced.data.lines.length, 2);
  assert.equal(replaced.data.restaurantId, 'R-CHECKOUT');
  assert.equal(replaced.data.instructions, 'Less spicy');

  const key = '901__M';
  const updated = await put(`/cart/items/${key}`, {
    customerId: 'cust-1',
    qty: 3,
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.data.lines.find((l) => l.key === key).qty, 3);

  const zero = await put(`/cart/items/${key}`, { customerId: 'cust-1', qty: 0 });
  assert.equal(zero.data.lines.length, 1);

  const removed = await del('/cart/items/901?customerId=cust-1');
  assert.equal(removed.data.lines.length, 0);

  await put('/cart', { customerId: 'cust-1', lines: [{ product, qty: 1 }] });
  const cleared = await del('/cart?customerId=cust-1');
  assert.equal(cleared.data.lines.length, 0);
});

test('wallet: empty, top-up disabled, Smart Change credit mirrored', async () => {
  const empty = await get('/wallet?customerId=cust-1');
  assert.equal(empty.status, 200);
  assert.equal(empty.data.balancePaise, 0);

  const topup = await post('/wallet/add', { customerId: 'cust-1', amount: 100 });
  assert.equal(topup.status, 501);
  assert.equal(topup.data.code, 'topup_disabled');

  const a = await post('/smart-change/activate', {
    customerId: 'cust-1',
    orderAmountPaise: 32000,
    cashAmountPaise: 50000,
    idempotencyKey: 'idem-wallet-1',
  });
  assert.equal(a.status, 201);
  await post(`/smart-change/${a.data.txnId}/link-order`, { orderId: 'OXRO900001' });
  const collected = await post(`/smart-change/${a.data.txnId}/collect`, {
    partnerId: 'partner-rider',
    actualCashPaise: 50000,
  });
  assert.equal(collected.status, 200);

  const wallet = await get('/wallet?customerId=cust-1');
  assert.equal(wallet.data.balancePaise, 18000);
  assert.equal(wallet.data.transactions.length, 1);
  assert.match(wallet.data.transactions[0].id, /^WTX/);

  // Replaying the same collect never double-credits.
  await post(`/smart-change/${a.data.txnId}/collect`, {
    partnerId: 'partner-rider',
    actualCashPaise: 50000,
  });
  const again = await get('/wallet?customerId=cust-1');
  assert.equal(again.data.balancePaise, 18000);
});

test('pricing: defaults + admin update bumps version', async () => {
  const initial = await get('/pricing');
  assert.equal(initial.status, 200);
  assert.equal(initial.data.config.platformFeePaise, 700);
  assert.equal(initial.data.config.version, 1);

  const updated = await put('/pricing', { platformFeePaise: 900 });
  assert.equal(updated.status, 200);
  assert.equal(updated.data.config.platformFeePaise, 900);
  assert.equal(updated.data.config.version, 2);

  const bad = await put('/pricing', { platformFeePaise: -1 });
  assert.equal(bad.status, 400);
});

test('checkout COD: creates order, clears cart, lists + tracks', async () => {
  await put('/cart', { customerId: 'cust-1', lines: [{ product, qty: 1 }] });
  const bill = billFor(79900);

  const placed = await post('/checkout/place', {
    customerId: 'cust-1',
    orderId: 'OXRO700001',
    products: [product],
    restaurantId: 'R-CHECKOUT',
    restaurantName: 'Checkout Kitchen',
    instructions: 'Less spicy',
    cutleryOptIn: true,
    paymentMethod: 'cod',
    bill,
  });
  assert.equal(placed.status, 201);
  assert.equal(placed.data.order.id, 'OXRO700001');
  assert.equal(placed.data.order.bill.grandTotalPaise, bill.grandTotalPaise);

  const cart = await get('/cart?customerId=cust-1');
  assert.equal(cart.data.lines.length, 0);

  const orders = await get('/orders?customerId=cust-1');
  assert.equal(orders.data.orders.length, 1);
  assert.equal(orders.data.orders[0].instructions, 'Less spicy');

  const tracking = await get('/orders/OXRO700001/tracking');
  assert.equal(tracking.status, 200);
  assert.equal(tracking.data.steps.length, 5);
  assert.equal(tracking.data.steps[0].label, 'Order Placed');

  const duplicate = await post('/checkout/place', {
    customerId: 'cust-1',
    orderId: 'OXRO700001',
    products: [product],
    paymentMethod: 'cod',
    bill,
  });
  assert.equal(duplicate.status, 409);
});

test('checkout: rejects a tampered bill and empty products', async () => {
  const tampered = billFor(79900, { grandTotalPaise: 1 });
  const bad = await post('/checkout/place', {
    customerId: 'cust-1',
    products: [product],
    paymentMethod: 'cod',
    bill: tampered,
  });
  assert.equal(bad.status, 400);

  const empty = await post('/checkout/place', {
    customerId: 'cust-1',
    products: [],
    paymentMethod: 'cod',
    bill: billFor(0),
  });
  assert.equal(empty.status, 400);
});

test('checkout wallet: insufficient is rejected, debit is exact', async () => {
  const bill = billFor(10000);
  const insufficient = await post('/checkout/place', {
    customerId: 'cust-2',
    products: [{ ...product, price: 100 }],
    paymentMethod: 'wallet',
    bill,
  });
  assert.equal(insufficient.status, 409);

  await walletStore.credit('cust-2', 50000, { txnId: 'seed-1', label: 'Seed' });
  const placed = await post('/checkout/place', {
    customerId: 'cust-2',
    products: [{ ...product, price: 100 }],
    paymentMethod: 'wallet',
    bill,
  });
  assert.equal(placed.status, 201);
  const wallet = await get('/wallet?customerId=cust-2');
  assert.equal(wallet.data.balancePaise, 50000 - bill.grandTotalPaise);
});

test('checkout verify rejects invalid signature', async () => {
  const { status, data } = await post('/checkout/verify', {
    razorpayOrderId: 'order_1',
    razorpayPaymentId: 'pay_1',
    razorpaySignature: 'bad-signature',
  });
  assert.equal(status, 400);
  assert.equal(data.code, 'payment_verification_failed');
});

test('search + restaurants come from the seeded catalogue', async () => {
  const found = await get('/search?q=biryani');
  assert.equal(found.status, 200);
  assert.ok(found.data.results.length > 0);
  assert.ok(found.data.results.some((d) => /Biryani/i.test(d.name)));

  const restaurants = await get('/restaurants');
  assert.equal(restaurants.status, 200);
  assert.ok(restaurants.data.restaurants.some((r) => r.id === 'r_paradise'));

  const menu = await get('/restaurants/r_paradise/menu');
  assert.equal(menu.status, 200);
  assert.ok(menu.data.menu.length > 0);
  assert.equal(menu.data.menu[0].restaurantId, 'r_paradise');
});

test('wishlist: add, list, remove', async () => {
  const empty = await get('/wishlist?customerId=cust-1');
  assert.deepEqual(empty.data.items, []);

  const added = await post('/wishlist', { customerId: 'cust-1', product });
  assert.equal(added.status, 200);
  assert.equal(added.data.items.length, 1);
  assert.equal(added.data.items[0].id, product.id);

  // Re-adding the same product is idempotent.
  await post('/wishlist', { customerId: 'cust-1', product });
  const again = await get('/wishlist?customerId=cust-1');
  assert.equal(again.data.items.length, 1);

  const removed = await del(`/wishlist/${product.id}?customerId=cust-1`);
  assert.equal(removed.data.items.length, 0);
});

test('reviews: upsert one per product + list', async () => {
  const empty = await get('/reviews?customerId=cust-1');
  assert.deepEqual(empty.data.reviews, []);

  const saved = await post('/reviews', {
    customerId: 'cust-1',
    productId: 901,
    rating: 4,
    body: 'Tasty!',
    photos: [1, 2],
    hasVideo: false,
  });
  assert.equal(saved.status, 201);
  assert.equal(saved.data.review.rating, 4);

  // Same product replaces (unique per customer+product).
  await post('/reviews', {
    customerId: 'cust-1',
    productId: 901,
    rating: 5,
    body: 'Loved it',
  });
  const list = await get('/reviews?customerId=cust-1');
  assert.equal(list.data.reviews.length, 1);
  assert.equal(list.data.reviews[0].rating, 5);

  const bad = await post('/reviews', {
    customerId: 'cust-1',
    productId: 901,
    rating: 9,
  });
  assert.equal(bad.status, 400);
});

test('support: create ticket + list', async () => {
  const created = await post('/support/tickets', {
    customerId: 'cust-1',
    source: 'order',
    categoryId: 'missing',
    categoryLabel: 'Missing item',
    orderId: 'OXRO700001',
    restaurantName: 'Checkout Kitchen',
    items: ['Paneer Tikka'],
    note: 'One item was missing',
  });
  assert.equal(created.status, 201);
  assert.equal(created.data.ticket.status, 'Submitted');

  const list = await get('/support/tickets?customerId=cust-1');
  assert.equal(list.data.tickets.length, 1);
  assert.equal(list.data.tickets[0].categoryId, 'missing');

  const bad = await post('/support/tickets', { customerId: 'cust-1', source: 'x' });
  assert.equal(bad.status, 400);
});

test('notifications: create, mark read, mark all read', async () => {
  const created = await post('/notifications', {
    customerId: 'cust-1',
    title: 'Order placed!',
    sub: 'Your order is being prepared',
    kind: 'order',
    icon: 57468,
    time: 'now',
  });
  assert.equal(created.status, 201);

  const list = await get('/notifications?customerId=cust-1');
  assert.equal(list.data.notifications.length, 1);
  assert.equal(list.data.notifications[0].unread, true);

  const id = created.data.notification.id;
  await put(`/notifications/${id}/read`, { customerId: 'cust-1', unread: false });
  const read = await get('/notifications?customerId=cust-1');
  assert.equal(read.data.notifications[0].unread, false);

  await put('/notifications/read-all', { customerId: 'cust-1' });
  const all = await get('/notifications?customerId=cust-1');
  assert.ok(all.data.notifications.every((n) => !n.unread));
});

test('premium + food preferences persist on the customer', async () => {
  const before = await get('/profile/premium?customerId=cust-1');
  assert.equal(before.data.isMember, false);

  const joined = await post('/profile/premium/join', { customerId: 'cust-1' });
  assert.equal(joined.data.isMember, true);

  const after = await get('/profile/premium?customerId=cust-1');
  assert.equal(after.data.isMember, true);
  assert.ok(after.data.joinedAt);

  const pref = await put('/profile/preferences', {
    customerId: 'cust-1',
    enabled: true,
    preference: 'veg',
  });
  assert.equal(pref.data.enabled, true);
  assert.equal(pref.data.preference, 'veg');

  const read = await get('/profile/preferences?customerId=cust-1');
  assert.equal(read.data.preference, 'veg');
});

test('search recents: push, list, remove, clear', async () => {
  await post('/search/recents', { customerId: 'cust-1', query: 'Biryani' });
  await post('/search/recents', { customerId: 'cust-1', query: 'Pizza' });
  const list = await get('/search/recents?customerId=cust-1');
  assert.equal(list.data.queries.length, 2);
  assert.equal(list.data.queries[0], 'Pizza'); // newest first

  await del('/search/recents?customerId=cust-1&query=Pizza');
  const after = await get('/search/recents?customerId=cust-1');
  assert.deepEqual(after.data.queries, ['Biryani']);

  await del('/search/recents?customerId=cust-1');
  const cleared = await get('/search/recents?customerId=cust-1');
  assert.deepEqual(cleared.data.queries, []);
});

test('coupons: served from the seeded table', async () => {
  const { status, data } = await get('/coupons');
  assert.equal(status, 200);
  assert.equal(data.coupons.length, 4);
  const code = data.coupons.find((c) => c.code === 'WELCOME10');
  assert.equal(code.percent, true);
  assert.equal(code.minOrder, 999);
});

test('dineout bookings: create + list', async () => {
  const created = await post('/dineout/bookings', {
    customerId: 'cust-1',
    restaurantId: 'd_verandah',
    guests: 4,
    slot: '8:00 PM',
    note: 'Window seat',
  });
  assert.equal(created.status, 201);
  assert.equal(created.data.booking.guests, 4);

  const list = await get('/dineout/bookings?customerId=cust-1');
  assert.equal(list.data.bookings.length, 1);

  const bad = await post('/dineout/bookings', {
    customerId: 'cust-1',
    restaurantId: 'd_verandah',
    guests: 0,
    slot: '8:00 PM',
  });
  assert.equal(bad.status, 400);
});
