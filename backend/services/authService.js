const authService = {
  registerUser: () => ({ registered: true, token: 'mock-jwt', status: 'scaffold' }),
  loginUser: () => ({ token: 'mock-jwt', status: 'scaffold' }),
  logout: () => ({ loggedOut: true, status: 'scaffold' }),
};

module.exports = authService;
