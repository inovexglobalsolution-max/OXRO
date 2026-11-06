'use strict';

const { isNonEmptyString } = require('../middleware/validateRequest');

/** Customer identity is a client string (`cust-<phone|email>` / `guest`). */
function customerIdFrom(req) {
  const raw = req.body && req.body.customerId;
  if (isNonEmptyString(raw)) return raw.trim();
  const query = req.query && req.query.customerId;
  if (isNonEmptyString(query)) return String(query).trim();
  return 'guest';
}

module.exports = { customerIdFrom };
