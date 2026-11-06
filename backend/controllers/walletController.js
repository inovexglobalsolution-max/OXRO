'use strict';

const store = require('../services/walletStore');
const { customerIdFrom } = require('../utils/request');

const walletController = {
  get: async (req, res) => {
    res.json(await store.get(customerIdFrom(req)));
  },

  /** Top-up stays disabled until a real payment gateway is integrated. */
  add: (req, res) => {
    res.status(501).json({
      error:
        'OXRO Money top-up is disabled until payment integration is complete.',
      code: 'topup_disabled',
    });
  },
};

module.exports = walletController;
