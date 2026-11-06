'use strict';

const store = require('../services/supportStore');
const { customerIdFrom } = require('../utils/request');

const supportController = {
  list: async (req, res) => {
    res.json({ tickets: await store.list(customerIdFrom(req)) });
  },

  create: async (req, res) => {
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.status(201).json({ ticket: out.ticket });
  },
};

module.exports = supportController;
