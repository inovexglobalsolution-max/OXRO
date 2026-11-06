'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/supportController');

router.get('/tickets', ctrl.list);
router.post('/tickets', ctrl.create);

module.exports = router;
