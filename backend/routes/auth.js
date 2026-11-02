const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');

router.post('/register', (req, res) => res.json({ registered: true, status: 'scaffold' }));
router.post('/login', (req, res) => {
  const token = jwt.sign({ userId: 'user_1' }, process.env.JWT_SECRET, { expiresIn: '1h' });
  res.json({ token, refreshToken: 'refresh_' + Date.now(), status: 'ok' });
});
router.post('/logout', (req, res) => res.json({ loggedOut: true, status: 'scaffold' }));

module.exports = router;
