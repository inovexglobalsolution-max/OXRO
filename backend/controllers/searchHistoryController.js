'use strict';

const store = require('../services/searchHistoryStore');
const { customerIdFrom } = require('../utils/request');

const searchHistoryController = {
  list: async (req, res) => {
    res.json({ queries: await store.list(customerIdFrom(req)) });
  },

  push: async (req, res) => {
    const query = (req.body || {}).query;
    res.json({ queries: await store.push(customerIdFrom(req), query) });
  },

  remove: async (req, res) => {
    const query = req.query.query;
    res.json({ queries: await store.remove(customerIdFrom(req), query) });
  },
};

module.exports = searchHistoryController;
