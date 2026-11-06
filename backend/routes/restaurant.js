'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/restaurantController');

router.get('/', ctrl.list);
router.get('/:id', ctrl.get);
router.get('/:id/menu', ctrl.menu);

module.exports = router;
