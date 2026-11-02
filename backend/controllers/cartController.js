const cartController = {
  list: (req, res) => res.json({ lines: [], status: 'scaffold' }),
  add: (req, res) => res.json({ added: true, status: 'scaffold' }),
  update: (req, res) => res.json({ updated: req.params.id, status: 'scaffold' }),
  remove: (req, res) => res.json({ removed: req.params.id, status: 'scaffold' }),
};

module.exports = cartController;
