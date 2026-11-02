const authController = {
  register: (req, res) => res.json({ registered: true, token: 'mock-jwt', status: 'scaffold' }),
  login: (req, res) => res.json({ token: 'mock-jwt', status: 'scaffold' }),
  logout: (req, res) => res.json({ loggedOut: true, status: 'scaffold' }),
};

module.exports = authController;
