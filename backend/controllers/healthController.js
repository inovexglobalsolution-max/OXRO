const { supabaseEnabled } = require('../config/supabase');

const healthController = {
  check: (req, res) => {
    res.status(200).json({
      status: 'ok',
      service: 'oxro-backend',
      timestamp: new Date().toISOString(),
      db: { enabled: supabaseEnabled() },
    });
  },
};

module.exports = healthController;
