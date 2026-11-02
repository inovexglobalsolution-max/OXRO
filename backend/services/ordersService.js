const ordersService = {
  getAll: () => ({ orders: [], status: 'scaffold' }),
  getById: (id) => ({ id, status: 'scaffold' }),
  trackingSteps: (id) => ({ steps: [], status: 'scaffold' }),
};

module.exports = ordersService;
