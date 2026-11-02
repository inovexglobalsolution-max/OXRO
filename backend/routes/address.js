const express = require('express');
const router = express.Router();

router.get('/', (req, res) => res.json({ addresses: [], status: 'scaffold' }));
router.post('/', (req, res) => res.json({ created: true, status: 'scaffold' }));

module.exports = router;
