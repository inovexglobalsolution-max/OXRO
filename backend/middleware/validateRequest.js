'use strict';

/**
 * Tiny request-validation helper.
 *
 * `validateRequest(validator)` returns Express middleware. The validator
 * receives the request and returns either a string (400 message) or null.
 */
function validateRequest(validator) {
  return (req, res, next) => {
    try {
      const error = validator(req);
      if (error) return res.status(400).json({ error });
      return next();
    } catch (e) {
      return next(e);
    }
  };
}

function isNonEmptyString(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

function isNonNegInt(v) {
  return Number.isInteger(v) && v >= 0;
}

function isPosInt(v) {
  return Number.isInteger(v) && v > 0;
}

module.exports = { validateRequest, isNonEmptyString, isNonNegInt, isPosInt };
