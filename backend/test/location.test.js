'use strict';

// Location / delivery-address phase — in-memory store only (no live Supabase).
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const addressStore = require('../services/addressStore');
const orderStore = require('../services/orderStore');

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
  addressStore.resetForTests();
  orderStore.resetForTests();
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

function billFor(itemSubtotalPaise) {
  const packagingPaise = 0;
  const deliveryPaise = itemSubtotalPaise > 19900 ? 0 : 4000;
  const platformFeePaise = 700;
  const smallCartFeePaise = itemSubtotalPaise < 9900 ? 1000 : 0;
  return {
    itemSubtotalPaise,
    packagingPaise,
    deliveryPaise,
    platformFeePaise,
    smallCartFeePaise,
    taxPaise: 0,
    tipPaise: 0,
    discountPaise: 0,
    grandTotalPaise:
      itemSubtotalPaise + deliveryPaise + platformFeePaise + smallCartFeePaise,
  };
}

const snapshot = {
  id: 'addr_loc_1',
  label: 'Home',
  name: 'Ravi Kumar',
  phone: '9876543210',
  line: '21 Greams Road',
  city: 'Chennai',
  state: 'Tamil Nadu',
  landmark: 'Near Apollo Hospitals',
  pin: '600006',
  latitude: 13.0827,
  longitude: 80.2707,
};

test('address: create with coordinates round-trips', async () => {
  const created = await post('/addresses', { customerId: 'cust-loc', ...snapshot });
  assert.equal(created.status, 201);
  assert.equal(created.data.address.latitude, 13.0827);
  assert.equal(created.data.address.longitude, 80.2707);
  assert.equal(created.data.address.state, 'Tamil Nadu');
  assert.equal(created.data.address.landmark, 'Near Apollo Hospitals');

  const listed = await get('/addresses?customerId=cust-loc');
  assert.equal(listed.status, 200);
  assert.equal(listed.data.addresses.length, 1);
  assert.equal(listed.data.addresses[0].latitude, 13.0827);
  assert.equal(listed.data.addresses[0].longitude, 80.2707);
});

test('address: invalid coordinates rejected, valid accepted', async () => {
  const badLat = await post('/addresses', { customerId: 'cust-loc', ...snapshot, latitude: 999 });
  assert.equal(badLat.status, 400);
  assert.equal(badLat.data.code, 'invalid_geo');

  const badLng = await post('/addresses', { customerId: 'cust-loc', ...snapshot, longitude: -999 });
  assert.equal(badLng.status, 400);
  assert.equal(badLng.data.code, 'invalid_geo');

  const ok = await post('/addresses', { customerId: 'cust-loc', ...snapshot, latitude: 19.076, longitude: 72.8777 });
  assert.equal(ok.status, 201);
  assert.equal(ok.data.address.latitude, 19.076);

  const updated = await put(`/addresses/${ok.data.address.id}`, {
    customerId: 'cust-loc',
    latitude: 12.9716,
    longitude: 77.5946,
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.data.address.latitude, 12.9716);
  assert.equal(updated.data.address.longitude, 77.5946);
});

test('address: coordinates survive create/update without being dropped', async () => {
  const created = await post('/addresses', { customerId: 'cust-loc', ...snapshot });
  assert.equal(created.status, 201);
  const id = created.data.address.id;
  const updatedNoCoords = await put(`/addresses/${id}`, {
    customerId: 'cust-loc',
    line: 'Updated line 42',
  });
  assert.equal(updatedNoCoords.status, 200);
  // Update with no coordinates must not silently wipe the stored point.
  assert.equal(updatedNoCoords.data.address.latitude, 13.0827);
  assert.equal(updatedNoCoords.data.address.longitude, 80.2707);
});

test('checkout place stores the delivery address snapshot', async () => {
  const placed = await post('/checkout/place', {
    orderId: 'OXROLOC000001',
    customerId: 'cust-loc',
    products: [
      {
        id: 901,
        name: 'Checkout Shirt',
        brand: 'OXRO',
        price: 799,
        mrp: 999,
        rating: 4.2,
        reviews: 100,
        icon: 0xe3a4,
        colors: [0xffffffff],
        restaurantId: 'R-LOC',
        restaurantName: 'Location Kitchen',
      },
    ],
    paymentMethod: 'cod',
    bill: billFor(79900),
    deliveryAddressSnapshot: snapshot,
  });
  assert.equal(placed.status, 201);
  assert.equal(placed.data.order.deliveryAddressSnapshot.latitude, 13.0827);
  assert.equal(placed.data.order.deliveryAddressSnapshot.longitude, 80.2707);
  assert.equal(placed.data.order.deliveryAddressSnapshot.line, '21 Greams Road');

  const list = await get('/orders?customerId=cust-loc');
  const stored = (list.data.orders || []).find((o) => o.id === 'OXROLOC000001');
  assert.ok(stored, 'order must be listed');
  assert.equal(stored.deliveryAddressSnapshot.latitude, 13.0827);
  assert.equal(stored.deliveryAddressSnapshot.longitude, 80.2707);
});

test('checkout place rejects an invalid delivery snapshot', async () => {
  const placed = await post('/checkout/place', {
    orderId: 'OXROLOC000002',
    customerId: 'cust-loc',
    products: [
      {
        id: 901,
        name: 'Checkout Shirt',
        brand: 'OXRO',
        price: 799,
        mrp: 999,
        rating: 4.2,
        reviews: 100,
        icon: 0xe3a4,
        colors: [0xffffffff],
      },
    ],
    paymentMethod: 'cod',
    bill: billFor(79900),
    deliveryAddressSnapshot: { ...snapshot, latitude: 'not-a-number' },
  });
  assert.equal(placed.status, 400);
  assert.equal(placed.data.code, 'invalid_delivery_snapshot');
});
