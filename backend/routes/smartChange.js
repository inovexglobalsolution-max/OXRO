'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/smartChangeController');

// Customer: confirm Smart Change (consent + cash amount).
router.post('/activate', ctrl.activate);

// Customer app: credited transactions pending local wallet application.
router.get('/credited', ctrl.credited);

// Delivery partner: Smart Change COD orders ready to collect.
router.get('/collectable', ctrl.collectable);

// Customer: link activated transaction to the placed order.
router.post('/:txnId/link-order', ctrl.linkOrder);

// Delivery partner: collect COD + server-verified wallet credit.
router.post('/:txnId/collect', ctrl.collect);

// Order cancellation workflow — no unauthorized wallet credit.
router.post('/:txnId/cancel', ctrl.cancel);

router.get('/:txnId', ctrl.getById);

module.exports = router;
