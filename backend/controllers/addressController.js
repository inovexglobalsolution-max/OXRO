const addressController = {
  list: (req, res) => res.json({ addresses: [], status: 'scaffold' }),
  create: (req, res) => res.json({ created: true, status: 'scaffold' }),
};

module.exports = addressController;
