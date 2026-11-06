'use strict';

const store = require('../services/couponStore');

const couponController = {
  list: async (req, res) => {
    res.json({ coupons: await store.list() });
  },
};

module.exports = couponController;
