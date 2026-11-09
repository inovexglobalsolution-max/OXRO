'use strict';

const store = require('../services/addressStore');
const { customerIdFrom } = require('../utils/request');

function fail(res, out) {
  return res.status(out.code || 400).json({ error: out.error });
}

function validateGeo(body = {}) {
  const lat = body.latitude;
  const lng = body.longitude;
  if (lat !== undefined && lat !== '') {
    if (!Number.isFinite(Number(lat)) || Number(lat) < -90 || Number(lat) > 90) {
      return 'latitude must be between -90 and 90';
    }
  }
  if (lng !== undefined && lng !== '') {
    if (!Number.isFinite(Number(lng)) || Number(lng) < -180 || Number(lng) > 180) {
      return 'longitude must be between -180 and 180';
    }
  }
  if (
    (lat === undefined) !== (lng === undefined) &&
    lat !== '' &&
    lng !== ''
  ) {
    return 'both latitude and longitude are required';
  }
  return null;
}

const addressController = {
  list: async (req, res) => {
    res.json(await store.list(customerIdFrom(req)));
  },

  create: async (req, res) => {
    const geoError = validateGeo(req.body || {});
    if (geoError) return res.status(400).json({ error: geoError, code: 'invalid_geo' });
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return fail(res, out);
    res.status(201).json({ address: out.address });
  },

  update: async (req, res) => {
    const geoError = validateGeo(req.body || {});
    if (geoError) return res.status(400).json({ error: geoError, code: 'invalid_geo' });
    const out = await store.update(customerIdFrom(req), req.params.id, req.body || {});
    if (out.error) return fail(res, out);
    res.json({ address: out.address });
  },

  select: async (req, res) => {
    const out = await store.select(customerIdFrom(req), req.params.id);
    if (out.error) return fail(res, out);
    res.json(out);
  },

  remove: async (req, res) => {
    const out = await store.remove(customerIdFrom(req), req.params.id);
    if (out.error) return fail(res, out);
    res.json(out);
  },
};

module.exports = addressController;
