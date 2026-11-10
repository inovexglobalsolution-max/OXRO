'use strict';

const profileStore = require('./profileStore');

function _fail(message, status, code) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  return err;
}

async function GoogleAuth(idToken) {
  const token = String(idToken || '').trim();
  if (!token) throw _fail('Missing Google ID token', 400, 'missing_token');

  const audience = process.env.GOOGLE_SERVER_CLIENT_ID;
  if (!audience || audience.includes('<paste')) {
    throw _fail(
      'Google sign-in is not configured',
      503,
      'google_not_configured',
    );
  }

  const res = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(token)}`,
  );
  const payload = await res.json().catch(() => null);
  if (!res.ok || !payload) {
    throw _fail('Invalid Google token', 401, 'invalid_token');
  }
  if (payload.aud !== audience) {
    throw _fail('Google token audience mismatch', 401, 'aud_mismatch');
  }
  if (payload.email_verified !== true && payload.email_verified !== 'true') {
    throw _fail('Google email not verified', 401, 'email_not_verified');
  }
  const email = String(payload.email || '').trim().toLowerCase();
  if (!email) {
    throw _fail('Google token has no email', 401, 'no_email');
  }
  const name = payload.name ? String(payload.name).trim() : undefined;
  const customerId = `cust-${email}`;
  await profileStore.upsert(customerId, {
    email,
    ...(name ? { name } : {}),
  });
  return { verified: true, email, name: name || null, customerId };
}

module.exports = { GoogleAuth };
