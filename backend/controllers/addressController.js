'use strict';

const store = require('../services/addressStore');
const { customerIdFrom } = require('../utils/request');

function fail(res, out) {
  return res.status(out.code || 400).json({ error: out.error });
}

const addressController = {
  list: async (req, res) => {
    res.json(await store.list(customerIdFrom(req)));
  },

  create: async (req, res) => {
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return fail(res, out);
    res.status(201).json({ address: out.address });
  },

  update: async (req, res) => {
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
