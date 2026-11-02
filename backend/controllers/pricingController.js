const pricingController = {
  getConfig: (req, res) => res.json({ config: {}, status: 'scaffold' }),
  updateConfig: (req, res) => res.json({ updated: true, status: 'scaffold' }),
};

module.exports = pricingController;
