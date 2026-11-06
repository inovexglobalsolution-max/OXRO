'use strict';

const express = require('express');
const ctrl = require('../controllers/checkoutController');

const router = express.Router();

router.post('/place', ctrl.place);
router.post('/verify', ctrl.verify);
router.post('/razorpay-order', ctrl.createRazorpayOrder);

module.exports = router;
