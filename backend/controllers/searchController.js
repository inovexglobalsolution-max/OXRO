const searchController = {
  search: (req, res) => res.json({ results: [], query: req.query.q || '', status: 'scaffold' }),
};

module.exports = searchController;
