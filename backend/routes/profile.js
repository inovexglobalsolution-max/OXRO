'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/profileController');

router.get('/me', ctrl.get);
router.put('/me', ctrl.put);
router.get('/premium', ctrl.premium);
router.post('/premium/join', ctrl.joinPremium);
router.post('/premium/cancel', ctrl.cancelPremium);
router.get('/preferences', ctrl.preferences);
router.put('/preferences', ctrl.setPreferences);

module.exports = router;
