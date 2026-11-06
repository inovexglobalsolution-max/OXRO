'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/dineoutController');

router.get('/bookings', ctrl.list);
router.post('/bookings', ctrl.create);

module.exports = router;
