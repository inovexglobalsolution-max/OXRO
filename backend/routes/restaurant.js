const express = require('express');
const router = express.Router();

router.get('/', (req, res) => res.json({ restaurants: [], status: 'scaffold' }));
router.get('/:id', (req, res) => res.json({ id: req.params.id, status: 'scaffold' }));
router.get('/:id/menu', (req, res) => res.json({ menu: [], status: 'scaffold' }));

module.exports = router;
