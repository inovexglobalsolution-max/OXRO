const express = require('express');
const router = express.Router();

router.get('/me', (req, res) => res.json({ profile: {}, status: 'scaffold' }));
router.put('/me', (req, res) => res.json({ updated: true, status: 'scaffold' }));

module.exports = router;
