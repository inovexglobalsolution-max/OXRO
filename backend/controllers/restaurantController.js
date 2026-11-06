'use strict';

const catalog = require('../services/catalogStore');

const restaurantController = {
  list: async (req, res) => {
    res.json({ restaurants: await catalog.asyncListRestaurants() });
  },

  get: async (req, res) => {
    const restaurant = await catalog.asyncGetRestaurant(req.params.id);
    if (!restaurant) {
      return res.status(404).json({ error: 'Restaurant not found' });
    }
    res.json({ restaurant });
  },

  menu: async (req, res) => {
    const menu = await catalog.asyncMenu(req.params.id);
    if (!menu) return res.status(404).json({ error: 'Restaurant not found' });
    res.json({ menu });
  },
};

module.exports = restaurantController;
