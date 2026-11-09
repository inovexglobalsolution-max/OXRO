'use strict';

const store = require('../services/supportStore');
const { customerIdFrom } = require('../utils/request');

const supportController = {
  list: async (req, res) => {
    const role = req.query.role ? String(req.query.role) : undefined;
    res.json({ tickets: await store.list(customerIdFrom(req), { role }) });
  },

  create: async (req, res) => {
    const out = await store.create(customerIdFrom(req), req.body || {});
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.status(201).json({ ticket: out.ticket });
  },

  update: async (req, res) => {
    const out = await store.setStatus(
      customerIdFrom(req),
      String(req.params.id || ''),
      String((req.body || {}).status || ''),
      { resolutionNotes: (req.body || {}).resolutionNotes },
    );
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.json({ ticket: out.ticket });
  },

  faqs: async (req, res) => {
    const role = String(req.query.role || 'customer');
    if (!['customer', 'restaurant', 'delivery'].includes(role)) {
      return res.status(400).json({ error: 'role must be customer, restaurant or delivery' });
    }
    res.json({ faqs: await store.listFaqs({ role }) });
  },
};

module.exports = supportController;
