'use strict';

const express = require('express');
const jwt = require('jsonwebtoken');
const emailAuth = require('../services/emailAuth');
const googleAuth = require('../services/googleAuth');
const profileStore = require('../services/profileStore');

const router = express.Router();

router.post('/register', (req, res) => res.json({ registered: true, status: 'scaffold' }));
router.post('/login', (req, res) => {
  const token = jwt.sign({ userId: 'user_1' }, process.env.JWT_SECRET, { expiresIn: '1h' });
  res.json({ token, refreshToken: 'refresh_' + Date.now(), status: 'ok' });
});
router.post('/logout', (req, res) => res.json({ loggedOut: true, status: 'scaffold' }));

router.post('/google', async (req, res, next) => {
  try {
    const idToken = (req.body || {}).idToken;
    const result = await googleAuth.GoogleAuth(idToken);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/send-otp', async (req, res, next) => {
  try {
    const email = (req.body || {}).email;
    const result = await emailAuth.sendOtp(email);
    res.json(result);
  } catch (err) {
    next(err);
  }
});

router.post('/verify-otp', async (req, res, next) => {
  try {
    const body = req.body || {};
    const result = await emailAuth.verifyOtp(body.email, body.token);
    const customerId = `cust-${result.email}`;
    const name = body.name === undefined ? undefined : String(body.name).trim();
    await profileStore.upsert(customerId, {
      email: result.email,
      ...(name ? { name } : {}),
    });
    res.json({ ...result, customerId });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
