const express = require('express');
const router = express.Router();

router.get('/', (req, res) => res.json({ balance: 0, transactions: [], status: 'scaffold' }));
router.post('/add', (req, res) => res.json({ added: true, status: 'scaffold' }));

module.exports = router;
