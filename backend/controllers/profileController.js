const profileController = {
  getMe: (req, res) => res.json({ profile: {}, status: 'scaffold' }),
  updateMe: (req, res) => res.json({ updated: true, status: 'scaffold' }),
};

module.exports = profileController;
