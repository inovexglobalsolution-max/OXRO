const express = require('express');
const router = express.Router();

router.get('/', (req, res) => res.json({ results: [], query: req.query.q || '', status: 'scaffold' }));

module.exports = router;
