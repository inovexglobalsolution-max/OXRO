const cartService = {
  getLines: () => ({ lines: [], status: 'scaffold' }),
  addItem: () => ({ added: true, status: 'scaffold' }),
  updateItem: (id) => ({ updated: id, status: 'scaffold' }),
  removeItem: (id) => ({ removed: id, status: 'scaffold' }),
};

module.exports = cartService;
