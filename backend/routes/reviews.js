'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/reviewController');

router.get('/', ctrl.list);
router.post('/', ctrl.upsert);

module.exports = router;
