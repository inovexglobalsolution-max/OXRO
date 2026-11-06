'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/addressController');

router.get('/', ctrl.list);
router.post('/', ctrl.create);
router.put('/:id', ctrl.update);
router.post('/:id/select', ctrl.select);
router.delete('/:id', ctrl.remove);

module.exports = router;
