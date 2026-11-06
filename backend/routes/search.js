'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/searchController');
const history = require('../controllers/searchHistoryController');

router.get('/', ctrl.search);
router.get('/recents', history.list);
router.post('/recents', history.push);
router.delete('/recents', history.remove);

module.exports = router;
