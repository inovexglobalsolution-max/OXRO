const express = require('express');
const router = express.Router();

router.post('/verify', (req, res) => {
  const { orderId, paymentId, amount } = req.body || {};
  if (!orderId || !paymentId || !amount) {
    return res.status(400).json({ error: 'Missing verification fields', verified: false });
  }
  res.json({ verified: true, orderId, paymentId, status: 'confirmed' });
});

router.post('/place', (req, res) => {
  res.json({ orderId: 'OXRO' + Date.now(), status: 'processing', verified: false });
});

module.exports = router;
