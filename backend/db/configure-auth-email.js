'use strict';

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const APPLY = process.argv.includes('--apply');

const FROM_NAME = process.env.RESEND_FROM_NAME || 'OXRO';
const SMTP_HOST = process.env.RESEND_SMTP_HOST || 'smtp.resend.com';
const SMTP_PORT = process.env.RESEND_SMTP_PORT || '465';
const SMTP_USER = process.env.RESEND_SMTP_USER || 'resend';
const SMTP_PASS = process.env.RESEND_API_KEY;
const SMTP_FROM = process.env.RESEND_FROM || 'OXRO <onboarding@resend.dev>';
const SMTP_FROM_EMAIL = (SMTP_FROM.match(/<([^>]+)>/) || [null, SMTP_FROM])[1].trim();

const TEMPLATE =
  '<h2>Your OXRO sign-in code</h2>' +
  '<p>Use this 6-digit code to sign in to OXRO:</p>' +
  '<p style="font-size:28px;letter-spacing:6px;font-weight:700">{{ .Token }}</p>' +
  '<p>This code expires in 1 hour. If you did not request it, you can ignore this email.</p>';

function projectRef() {
  try {
    const host = new URL(process.env.SUPABASE_URL || '').hostname;
    return host.split('.')[0] || '';
  } catch {
    return '';
  }
}

function missing() {
  const required = [
    'SUPABASE_ACCESS_TOKEN',
    'SUPABASE_URL',
    'RESEND_API_KEY',
    'RESEND_FROM',
  ];
  return required.filter((key) => {
    const v = process.env[key];
    return !v || String(v).trim() === '' || String(v).includes('<paste');
  });
}

function redact(value) {
  const s = String(value || '');
  if (s.length <= 4) return '****';
  return `${'*'.repeat(Math.min(s.length - 4, 12))}${s.slice(-4)}`;
}

async function request(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${process.env.SUPABASE_ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  if (!res.ok) {
    const msg = json ? JSON.stringify(json) : text;
    throw new Error(`Management API ${res.status}: ${msg}`);
  }
  return json;
}

async function main() {
  const absent = missing();
  if (absent.length) {
    console.error(`Missing/placeholder env keys: ${absent.join(', ')}`);
    process.exit(1);
  }
  const ref = projectRef();
  if (!ref) {
    console.error('Could not derive project ref from SUPABASE_URL');
    process.exit(1);
  }

  const base = `https://api.supabase.com/v1/projects/${ref}/config/auth`;
  const current = await request('GET', base);

  console.log(`Project ref: ${ref}`);
  console.log(`Current: external_email_enabled=${!!current.external_email_enabled}`);
  console.log(`Current: smtp_host=${current.smtp_host ? 'configured' : 'not configured'}`);
  console.log(
    `Current: magic_link template has {{ .Token }}=${String(
      current.mailer_templates_magic_link_content || '',
    ).includes('{{ .Token }}')}`,
  );

  const patch = {
    external_email_enabled: true,
    mailer_autoconfirm: false,
    mailer_otp_length: 6,
    mailer_otp_exp: 3600,
    smtp_host: SMTP_HOST,
    smtp_port: SMTP_PORT,
    smtp_user: SMTP_USER,
    smtp_pass: SMTP_PASS,
    smtp_admin_email: SMTP_FROM_EMAIL,
    smtp_sender_name: process.env.RESEND_FROM_NAME ? FROM_NAME : 'OXRO',
    mailer_subjects_magic_link: 'Your OXRO sign-in code',
    mailer_templates_magic_link_content: TEMPLATE,
    mailer_subjects_confirmation: 'Your OXRO sign-in code',
    mailer_templates_confirmation_content: TEMPLATE,
  };

  console.log('\nPlanned changes:');
  console.log(`  smtp_host            ${SMTP_HOST}`);
  console.log(`  smtp_port            ${SMTP_PORT}`);
  console.log(`  smtp_user            ${redact(patch.smtp_user)}`);
  console.log(`  smtp_pass            ${redact(patch.smtp_pass)}`);
  console.log(`  smtp_admin_email     ${patch.smtp_admin_email}`);
  console.log(`  smtp_sender_name     ${patch.smtp_sender_name}`);
  console.log(`  magic_link template  includes {{ .Token }} (6-digit code)`);
  console.log(`  confirmation template includes {{ .Token }} (6-digit code)`);
  console.log(`  mailer_otp_length    6`);
  console.log(`  mailer_otp_exp       3600`);

  if (!APPLY) {
    console.log('\nDry run only. Re-run with --apply to patch the project.');
    return;
  }

  await request('PATCH', base, patch);
  const afterConfig = await request('GET', base);
  const okSmtp = afterConfig.smtp_host === SMTP_HOST;
  const okTemplate = String(
    afterConfig.mailer_templates_magic_link_content || '',
  ).includes('{{ .Token }}');
  const okConfirmation = String(
    afterConfig.mailer_templates_confirmation_content || '',
  ).includes('{{ .Token }}');

  console.log('\nPatch applied.');
  console.log(`  smtp_host configured: ${okSmtp}`);
  console.log(`  magic_link template has {{ .Token }}: ${okTemplate}`);
  console.log(`  confirmation template has {{ .Token }}: ${okConfirmation}`);
  if (!okSmtp || !okTemplate || !okConfirmation) process.exit(1);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
