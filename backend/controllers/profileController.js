'use strict';

const store = require('../services/profileStore');
const { customerIdFrom } = require('../utils/request');

const profileController = {
  get: async (req, res) => {
    const customerId = customerIdFrom(req);
    res.json({ profile: await store.get(customerId) });
  },

  put: async (req, res) => {
    const customerId = customerIdFrom(req);
    const { name, email, phone } = req.body || {};
    const profile = await store.upsert(customerId, { name, email, phone });
    res.json({ profile });
  },

  premium: async (req, res) => {
    res.json(await store.getPremium(customerIdFrom(req)));
  },

  joinPremium: async (req, res) => {
    res.json(await store.joinPremium(customerIdFrom(req)));
  },

  cancelPremium: async (req, res) => {
    res.json(await store.cancelPremium(customerIdFrom(req)));
  },

  preferences: async (req, res) => {
    res.json(await store.getPreferences(customerIdFrom(req)));
  },

  setPreferences: async (req, res) => {
    res.json(await store.setPreferences(customerIdFrom(req), req.body || {}));
  },
};

module.exports = profileController;
