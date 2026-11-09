'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/walletController');

router.get('/', ctrl.get);
router.post('/add', ctrl.add);
router.get('/transactions', ctrl.transactions);
router.post('/create-order', ctrl.createOrder);
router.post('/verify-payment', ctrl.verifyPayment);
router.post('/razorpay-webhook', express.raw({ type: '*/*' }), ctrl.webhook);

module.exports = router;
