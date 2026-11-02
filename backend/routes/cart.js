const express = require('express');
const router = express.Router();

router.get('/', (req, res) => res.json({ lines: [], status: 'scaffold' }));
router.post('/', (req, res) => res.json({ added: true, status: 'scaffold' }));
router.put('/:id', (req, res) => res.json({ updated: req.params.id, status: 'scaffold' }));
router.delete('/:id', (req, res) => res.json({ removed: req.params.id, status: 'scaffold' }));

module.exports = router;
