const express = require('express');
const router = express.Router();

router.get('/', (req, res) => res.json({ config: {}, status: 'scaffold' }));
router.put('/', (req, res) => res.json({ updated: true, status: 'scaffold' }));

module.exports = router;
