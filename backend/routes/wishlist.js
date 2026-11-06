'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/wishlistController');

router.get('/', ctrl.list);
router.post('/', ctrl.add);
router.delete('/:productId', ctrl.remove);

module.exports = router;
