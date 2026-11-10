'use strict';

const { createClient } = require('@supabase/supabase-js');

let _testClient = null;

function _looksReal(value) {
  return typeof value === 'string' && value.length > 8 && !value.includes('<paste');
}

function _client() {
  if (_testClient) return _testClient;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!_looksReal(url) || !_looksReal(key)) return null;
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function _fail(message, status, code) {
  const err = new Error(message);
  err.status = status;
  err.code = code;
  return err;
}

function _email(value) {
  const email = String(value || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw _fail('Enter a valid email address', 400, 'invalid_email');
  }
  return email;
}

function _token(value) {
  const token = String(value || '').replace(/\D/g, '');
  if (!/^\d{6}$/.test(token)) {
    throw _fail('Enter the 6-digit code', 400, 'invalid_token');
  }
  return token;
}

function _mapAuthError(error, fallbackStatus, fallbackCode) {
  const msg = (error && error.message) || 'Authentication failed';
  const status = Number(error && error.status) || fallbackStatus;
  if (status === 429 || /rate/i.test(msg)) {
    return _fail('Too many attempts — please wait a minute and try again', 429, 'rate_limited');
  }
  return _fail(msg, fallbackStatus, fallbackCode);
}

async function sendOtp(email) {
  const normalized = _email(email);
  const client = _client();
  if (!client) {
    throw _fail('Email sign-in is not configured', 503, 'auth_not_configured');
  }
  const { error } = await client.auth.signInWithOtp({
    email: normalized,
    options: { shouldCreateUser: true },
  });
  if (error) throw _mapAuthError(error, 400, 'send_failed');
  return { sent: true, email: normalized };
}

async function verifyOtp(email, token) {
  const normalized = _email(email);
  const code = _token(token);
  const client = _client();
  if (!client) {
    throw _fail('Email sign-in is not configured', 503, 'auth_not_configured');
  }
  const { data, error } = await client.auth.verifyOtp({
    email: normalized,
    token: code,
    type: 'email',
  });
  if (error) throw _mapAuthError(error, 401, 'invalid_code');
  const user = (data && data.user) || null;
  return {
    verified: true,
    email: normalized,
    userId: user ? user.id : null,
  };
}

function resetForTests() {
  _testClient = null;
}

function setClientForTests(client) {
  _testClient = client;
}

module.exports = {
  sendOtp,
  verifyOtp,
  resetForTests,
  setClientForTests,
};
