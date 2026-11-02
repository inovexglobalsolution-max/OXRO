const restaurantController = {
  list: (req, res) => res.json({ restaurants: [], status: 'scaffold' }),
  getById: (req, res) => res.json({ id: req.params.id, status: 'scaffold' }),
  menu: (req, res) => res.json({ menu: [], status: 'scaffold' }),
};

module.exports = restaurantController;
