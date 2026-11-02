const profileService = {
  getProfile: () => ({ profile: {}, status: 'scaffold' }),
  updateProfile: () => ({ updated: true, status: 'scaffold' }),
};

module.exports = profileService;
