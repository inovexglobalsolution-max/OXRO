'use strict';

const catalog = require('../services/catalogStore');

const searchController = {
  search: async (req, res) => {
    const q = String(req.query.q || '').trim();
    const limit = Math.min(Number(req.query.limit) || 60, 100);
    const safeLimit = limit > 0 ? limit : 60;
    res.json({
      query: q,
      results: q ? await catalog.asyncSearchDishes(q, safeLimit) : [],
      restaurants: q ? await catalog.asyncSearchRestaurants(q, 6) : [],
    });
  },
};

module.exports = searchController;
