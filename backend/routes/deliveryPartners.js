'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/deliveryPartnerController');

router.get('/', ctrl.list);
router.get('/:id/location', ctrl.location.get);
router.post('/:id/location', ctrl.location.upsert);

module.exports = router;
