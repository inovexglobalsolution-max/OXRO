'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/walletController');

router.get('/', ctrl.get);
router.post('/add', ctrl.add);

module.exports = router;
