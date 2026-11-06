'use strict';

const store = require('../services/wishlistStore');
const { customerIdFrom } = require('../utils/request');

const wishlistController = {
  list: async (req, res) => {
    res.json({ items: await store.list(customerIdFrom(req)) });
  },

  add: async (req, res) => {
    const body = req.body || {};
    const product = body.product;
    if (!product || product.id == null) {
      return res.status(400).json({ error: 'product with an id is required' });
    }
    res.json({ items: await store.add(customerIdFrom(req), product) });
  },

  remove: async (req, res) => {
    const productId = Number(req.params.productId);
    if (!Number.isInteger(productId)) {
      return res.status(400).json({ error: 'productId must be an integer' });
    }
    res.json({ items: await store.remove(customerIdFrom(req), productId) });
  },
};

module.exports = wishlistController;
