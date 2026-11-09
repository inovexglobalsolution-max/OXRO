'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/deliveryPartnerController');

router.get('/orders/:id/live-tracking', ctrl.tracking);
router.post('/orders/:id/assign-partner', ctrl.assignment.assign);
router.post('/orders/:id/pick-up', ctrl.assignment.pickup);
router.post('/orders/:id/delivered', ctrl.assignment.delivered);
router.get('/orders/:id/messages', ctrl.messages.list);
router.post('/orders/:id/messages', ctrl.messages.send);
router.post('/orders/:id/delivery-instructions', ctrl.deliveryInstructions);

module.exports = router;
