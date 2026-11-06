'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/cartController');

router.get('/', ctrl.get);
router.put('/', ctrl.replace);
router.delete('/', ctrl.clear);
router.post('/items', ctrl.addItem);
router.put('/items/:key', ctrl.updateItem);
router.delete('/items/:key', ctrl.removeItem);

module.exports = router;
