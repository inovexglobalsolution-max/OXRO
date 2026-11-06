'use strict';

const store = require('../services/reviewStore');
const { customerIdFrom } = require('../utils/request');

const reviewController = {
  list: async (req, res) => {
    res.json({ reviews: await store.list(customerIdFrom(req)) });
  },

  upsert: async (req, res) => {
    const out = await store.upsert(customerIdFrom(req), req.body || {});
    if (out.error) return res.status(out.code || 400).json({ error: out.error });
    res.status(201).json({ review: out.review });
  },
};

module.exports = reviewController;
