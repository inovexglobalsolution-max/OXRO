'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/notificationController');

router.get('/', ctrl.list);
router.post('/', ctrl.create);
router.put('/read-all', ctrl.markAllRead);
router.put('/:id/read', ctrl.markRead);

module.exports = router;
