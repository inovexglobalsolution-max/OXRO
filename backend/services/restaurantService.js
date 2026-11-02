const restaurantService = {
  getAll: () => ({ restaurants: [], status: 'scaffold' }),
  getById: (id) => ({ id, status: 'scaffold' }),
  getMenu: (id) => ({ menu: [], status: 'scaffold' }),
};

module.exports = restaurantService;
