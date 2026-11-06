'use strict';

const store = require('../services/dineoutStore');
const { customerIdFrom } = require('../utils/request');

const dineoutController = {
  list: async (req, res) => {
    res.json({ bookings: await store.list(customerIdFrom(req)) });
  },

  create: async (req, res) => {
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.status(201).json({ booking: out.booking });
  },
};

module.exports = dineoutController;
