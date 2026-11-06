'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/pricingController');

router.get('/', ctrl.get);
router.put('/', ctrl.update);
router.post('/', ctrl.update);

module.exports = router;
