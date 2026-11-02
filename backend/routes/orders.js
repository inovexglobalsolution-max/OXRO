const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  res.json({ message: 'Orders endpoint', status: 'scaffold' });
});

router.get('/:id', (req, res) => {
  res.json({ message: 'Order detail', id: req.params.id, status: 'scaffold' });
});

router.get('/:id/tracking', (req, res) => {
  res.json({ message: 'Tracking steps', id: req.params.id, status: 'scaffold' });
});

module.exports = router;
