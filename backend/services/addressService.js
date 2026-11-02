const addressService = {
  getAddresses: () => ({ addresses: [], status: 'scaffold' }),
  createAddress: () => ({ created: true, status: 'scaffold' }),
};

module.exports = addressService;
