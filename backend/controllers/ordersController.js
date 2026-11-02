const ordersController = {
  list: (req, res) => res.json({ orders: [], status: 'scaffold' }),
  getById: (req, res) => res.json({ id: req.params.id, status: 'scaffold' }),
  tracking: (req, res) => res.json({ steps: [], status: 'scaffold' }),
};

module.exports = ordersController;
