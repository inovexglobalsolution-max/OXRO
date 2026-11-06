'use strict';

const store = require('../services/cartStore');
const { customerIdFrom } = require('../utils/request');

function fail(res, out) {
  return res.status(out.code || 400).json({ error: out.error });
}

const cartController = {
  get: async (req, res) => {
    res.json(await store.get(customerIdFrom(req)));
  },

  replace: async (req, res) => {
    const out = await store.replace(customerIdFrom(req), req.body || {});
    res.json(out.cart);
  },

  addItem: async (req, res) => {
    const out = await store.upsertLine(customerIdFrom(req), req.body || {});
    if (out.error) return fail(res, out);
    res.status(201).json(out.cart);
  },

  updateItem: async (req, res) => {
    const out = await store.updateLine(
      customerIdFrom(req),
      req.params.key,
      req.body || {},
    );
    if (out.error) return fail(res, out);
    res.json(out.cart);
  },

  removeItem: async (req, res) => {
    const out = await store.removeLine(customerIdFrom(req), req.params.key);
    if (out.error) return fail(res, out);
    res.json(out.cart);
  },

  clear: async (req, res) => {
    const out = await store.clear(customerIdFrom(req));
    res.json(out.cart);
  },
};

module.exports = cartController;
