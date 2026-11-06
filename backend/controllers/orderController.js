'use strict';

const store = require('../services/orderStore');
const { customerIdFrom } = require('../utils/request');

const orderController = {
  list: async (req, res) => {
    res.json({ orders: await store.listByCustomer(customerIdFrom(req)) });
  },

  get: async (req, res) => {
    const order = await store.get(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json({ order });
  },

  tracking: async (req, res) => {
    const steps = await store.trackingSteps(req.params.id);
    if (!steps) return res.status(404).json({ error: 'Order not found' });
    res.json({ steps });
  },

  cancel: async (req, res) => {
    const out = await store.cancel(req.params.id);
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.json({ order: out.order, duplicate: !!out.duplicate });
  },
};

module.exports = orderController;
