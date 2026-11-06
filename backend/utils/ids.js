'use strict';

const crypto = require('crypto');

/** Prefix + random hex, e.g. `addr_3f9c1a2b4d5e`. */
function newId(prefix = 'id') {
  return `${prefix}_${crypto.randomBytes(6).toString('hex')}`;
}

/** Customer-facing order id, e.g. `OXRO12345742`. */
function newOrderId() {
  return `OXRO${Date.now().toString().slice(-6)}${crypto.randomInt(10, 100)}`;
}

function nowIso() {
  return new Date().toISOString();
}

/** Accepts a client-supplied id when it is a safe, non-empty string. */
function safeId(candidate, prefix) {
  if (typeof candidate === 'string' && /^[A-Za-z0-9_-]{1,64}$/.test(candidate)) {
    return candidate;
  }
  return newId(prefix);
}

module.exports = { newId, newOrderId, nowIso, safeId };
