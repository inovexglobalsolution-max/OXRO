const pricingService = {
  getConfig: () => ({ config: {}, status: 'scaffold' }),
  updateConfig: () => ({ updated: true, status: 'scaffold' }),
};

module.exports = pricingService;
