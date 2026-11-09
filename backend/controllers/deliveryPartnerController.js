'use strict';

const dpStore = require('../services/deliveryPartnerStore');
const orderStore = require('../services/orderStore');
const messages = require('../services/orderMessages');
const { safeId } = require('../utils/ids');

const EARTH_RADIUS_KM = 6371;
const AVG_SPEED_KMH = 22; // realistic city scooter average

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

function haversineKm(a, b) {
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.latitude)) * Math.cos(toRad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(s)));
}

function snapshotCoords(order) {
  const snap = order && order.deliveryAddressSnapshot;
  if (snap && Number.isFinite(snap.latitude) && Number.isFinite(snap.longitude)) {
    return { latitude: snap.latitude, longitude: snap.longitude };
  }
  // Fallback: store coords on the address if migrated to the order directly.
  if (order && Number.isFinite(order.latitude) && Number.isFinite(order.longitude)) {
    return { latitude: order.latitude, longitude: order.longitude };
  }
  return null;
}

function etaMinutes(status, restaurantEtaMinutes, distanceKm) {
  if (status === 'delivered' || status === 'cancelled') return 0;
  if (status === 'outForDelivery' && distanceKm != null) {
    return Math.max(1, Math.round((distanceKm / AVG_SPEED_KMH) * 60));
  }
  return restaurantEtaMinutes || 30;
}

const deliveryPartnerController = {
  list: async (req, res) => {
    const partners = await dpStore.listPartners();
    res.json({ partners });
  },

  location: {
    upsert: async (req, res) => {
      const partnerId = req.params.id;
      const out = await dpStore.upsertLocation(partnerId, req.body || {});
      if (out.error) return res.status(out.code || 400).json({ error: out.error });
      res.json({ location: out.location });
    },
    get: async (req, res) => {
      const loc = await dpStore.getLocation(req.params.id);
      if (!loc) return res.status(404).json({ error: 'Location not available' });
      res.json({ location: loc });
    },
  },

  assignment: {
    assign: async (req, res) => {
      const orderId = safeId(req.params.id, 'OXRO');
      const partnerId = String((req.body && req.body.partnerId) || '').trim();
      if (!partnerId) return res.status(400).json({ error: 'partnerId is required' });
      const out = await dpStore.assignOrder(orderId, partnerId);
      if (out.error) return res.status(out.code || 400).json({ error: out.error });
      res.json({ assignment: out.assignment });
    },
    pickup: async (req, res) => {
      const out = await dpStore.markPickedUp(req.params.id);
      if (out.error) return res.status(out.code || 400).json({ error: out.error });
      res.json({ assignment: out.assignment });
    },
    delivered: async (req, res) => {
      const out = await dpStore.markDelivered(req.params.id);
      if (out.error) return res.status(out.code || 400).json({ error: out.error });
      res.json({ assignment: out.assignment });
    },
  },

  tracking: async (req, res) => {
    const orderId = safeId(req.params.id, 'OXRO');
    const order = await orderStore.get(orderId);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    const { assignment, partner, location } = await dpStore.tracking(orderId);
    const customerCoords = snapshotCoords(order);
    const distanceKm =
      location && customerCoords
        ? haversineKm(
            { latitude: location.latitude, longitude: location.longitude },
            customerCoords,
          )
        : null;
    const restaurantEta = 30; // until restaurants expose live ETA
    const eta = etaMinutes(order.status, restaurantEta, distanceKm);
    res.json({
      orderId: order.id,
      status: order.status,
      estimatedArrivalMinutes: eta,
      etaLabel: eta <= 0 ? 'Arriving now' : `${eta} min`,
      partner: partner
        ? {
            id: partner.id,
            name: partner.name,
            phone: partner.phone || null,
            photoUrl: partner.photoUrl || null,
            rating: partner.rating,
            completedDeliveries: partner.completedDeliveries,
            vehicleType: partner.vehicleType,
            vehicleNumber: partner.vehicleNumber,
            verified: partner.verified,
          }
        : null,
      partnerLocation: location,
      assignedAt: assignment ? assignment.assignedAt : null,
      pickedUpAt: assignment ? assignment.pickedUpAt : null,
      deliveredAt: assignment ? assignment.deliveredAt : null,
      deliveryInstructions: order.instructions || null,
      customerCoordinates: customerCoords,
      restaurant: {
        id: order.restaurantId || null,
        name: order.restaurantName || null,
      },
      cutleryOptIn: order.cutleryOptIn ?? null,
      // No service currently advertises the on-time guarantee — never claim it.
      guarantee: { eligible: false, text: null },
    });
  },

  messages: {
    list: async (req, res) => {
      const orderId = safeId(req.params.id, 'OXRO');
      const list = await messages.list(orderId);
      if (list.error) {
        return res.status(list.code || 502).json({ error: list.error });
      }
      res.json({ messages: list.messages });
    },
    send: async (req, res) => {
      const orderId = safeId(req.params.id, 'OXRO');
      const body = String((req.body && req.body.body) || '').trim();
      if (!body) return res.status(400).json({ error: 'body is required' });
      if (body.length > 1000) return res.status(400).json({ error: 'body too long' });
      const senderRole = String((req.body && req.body.senderRole) || 'customer');
      if (!['customer', 'partner'].includes(senderRole)) {
        return res.status(400).json({ error: 'senderRole must be customer or partner' });
      }
      const out = await messages.send(orderId, senderRole, body);
      if (out.error) return res.status(out.code || 502).json({ error: out.error });
      res.status(201).json({ message: out.message });
    },
  },

  deliveryInstructions: async (req, res) => {
    const orderId = safeId(req.params.id, 'OXRO');
    const order = await orderStore.get(orderId);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    if (['delivered', 'cancelled'].includes(order.status)) {
      return res
        .status(409)
        .json({ error: 'Instructions can no longer be changed for this order' });
    }
    const text = String((req.body && req.body.instructions) || '').trim();
    const patch = text || null;
    const updated = await orderStore.update(orderId, { instructions: patch });
    if (!updated) return res.status(500).json({ error: 'Could not update instructions' });
    res.json({ instructions: updated.instructions ?? patch });
  },
};

module.exports = deliveryPartnerController;
