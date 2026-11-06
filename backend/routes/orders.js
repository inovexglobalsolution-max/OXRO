'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/orderController');

router.get('/', ctrl.list);
router.get('/:id', ctrl.get);
router.get('/:id/tracking', ctrl.tracking);
router.post('/:id/cancel', ctrl.cancel);

module.exports = router;
