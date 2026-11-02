const healthService = {
  getStatus: () => {
    return {
      status: 'ok',
      service: 'oxro-backend',
      timestamp: new Date().toISOString(),
    };
  },
};

module.exports = healthService;
