'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/dineoutController');

router.get('/bookings', ctrl.list);
router.post('/bookings', ctrl.create);
router.post('/bookings/create-payment-order', ctrl.createPaymentOrder);
router.post('/bookings/confirm-booking', ctrl.confirmBooking);

module.exports = router;
