'use strict';

const store = require('../services/pricingStore');

const pricingController = {
  get: async (req, res) => {
    res.json({ config: await store.get() });
  },

  update: async (req, res) => {
    const body = req.body || {};
    const patch = body.config && typeof body.config === 'object' ? body.config : body;
    const out = await store.update(patch);
    if (out.error) return res.status(400).json({ error: out.error });
    res.json({ config: out.config });
  },
};

module.exports = pricingController;
