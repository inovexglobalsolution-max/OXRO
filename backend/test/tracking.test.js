'use strict';

// Delivery partner live tracking â€” in-memory only.
process.env.SUPABASE_URL = '';
process.env.SUPABASE_SECRET_KEY = '';

const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

const orderStore = require('../services/orderStore');
const dpStore = require('../services/deliveryPartnerStore');
const messages = require('../services/orderMessages');

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
  orderStore.resetForTests();
  dpStore.resetForTests();
  messages.resetForTests();
  dpStore.seedPartnerForTests({ id: 'DP001', name: 'Rahul Kumar' });
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

const get = (p) => call('GET', p);
const post = (p, b) => call('POST', p, b);

function billFor(itemSubtotalPaise) {
  const packagingPaise = 0;
  const deliveryPaise = 0;
  const platformFeePaise = 700;
  const smallCartFeePaise = 0;
  return {
    itemSubtotalPaise,
    packagingPaise,
    deliveryPaise,
    platformFeePaise,
    smallCartFeePaise,
    taxPaise: 0,
    tipPaise: 0,
    discountPaise: 0,
    grandTotalPaise: itemSubtotalPaise + platformFeePaise,
  };
}

const snapshot = {
  id: 'addr_track_1',
  label: 'Home',
  name: 'Ravi Kumar',
  phone: '9876543210',
  line: '21 Greams Road',
  city: 'Chennai',
  state: 'Tamil Nadu',
  landmark: 'Near Apollo',
  pin: '600006',
  latitude: 13.0827,
  longitude: 80.2707,
};

async function createOrder() {
  const placed = await post('/checkout/place', {
    orderId: 'OXROTRACK001',
    customerId: 'cust-track',
    products: [
      {
        id: 901,
        name: 'Track Shirt',
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
    deliveryAddressSnapshot: snapshot,
  });
  assert.equal(placed.status, 201);
  return placed.data.order;
}

test('tracking payload reflects assignment + live location + ETA', async () => {
  await createOrder();

  const before = await get('/orders/OXROTRACK001/live-tracking');
  assert.equal(before.status, 200);
  assert.equal(before.data.status, 'processing');
  assert.equal(before.data.partner, null);
  assert.equal(before.data.customerCoordinates.latitude, 13.0827);
  assert.equal(before.data.estimatedArrivalMinutes, 30);

  const assigned = await post('/orders/OXROTRACK001/assign-partner', {
    partnerId: 'DP001',
  });
  assert.equal(assigned.status, 200);

  const loc = await post('/delivery-partners/DP001/location', {
    latitude: 13.05,
    longitude: 80.25,
    accuracy: 8,
  });
  assert.equal(loc.status, 200);

  const after = await get('/orders/OXROTRACK001/live-tracking');
  assert.equal(after.status, 200);
  assert.equal(after.data.partner.name, 'Rahul Kumar');
  assert.equal(after.data.partner.phone, '9876543210');
  assert.equal(after.data.partnerLocation.latitude, 13.05);
  assert.equal(after.data.assignedAt != null, true);
  assert.ok(after.data.estimatedArrivalMinutes <= 30);

  const picked = await post('/orders/OXROTRACK001/pick-up', {});
  assert.equal(picked.status, 200);
});

test('delivery instructions round-trip through the tracking payload', async () => {
  await createOrder();
  const instructions = await post('/orders/OXROTRACK001/delivery-instructions', {
    instructions: 'Leave at the door, please',
  });
  assert.equal(instructions.status, 200);
  const t = await get('/orders/OXROTRACK001/live-tracking');
  assert.equal(t.data.deliveryInstructions, 'Leave at the door, please');
});

test('order messages list/send round-trip', async () => {
  await createOrder();
  const empty = await get('/orders/OXROTRACK001/messages');
  assert.equal(empty.status, 200);
  assert.deepEqual(empty.data.messages, []);

  const sent = await post('/orders/OXROTRACK001/messages', {
    senderRole: 'customer',
    body: 'Please ring the bell',
  });
  assert.equal(sent.status, 201);
  assert.equal(sent.data.message.body, 'Please ring the bell');

  const list = await get('/orders/OXROTRACK001/messages');
  assert.equal(list.data.messages.length, 1);
  assert.equal(list.data.messages[0].senderRole, 'customer');
});

test('partner location requires valid coordinates', async () => {
  await createOrder();
  const bad = await post('/delivery-partners/DP001/location', {
    latitude: 999,
    longitude: 80,
  });
  assert.equal(bad.status, 400);
  const missing = await post('/delivery-partners/DP001/location', {});
  assert.equal(missing.status, 400);
});

