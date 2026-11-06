'use strict';
// Runs backend/db/schema.sql through the Supabase Management API.
// Token is read from backend/.env (never printed).
const fs = require('fs');
const path = require('path');

require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const token = process.env.SUPABASE_ACCESS_TOKEN;
const ref = 'rmsrzsceuvbykcvoapet';
if (!token || !token.startsWith('sbp_')) {
  console.error('SUPABASE_ACCESS_TOKEN missing/invalid');
  process.exit(1);
}

const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');

async function run() {
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  const text = await res.text();
  console.log('HTTP', res.status);
  console.log(text.slice(0, 2000));
  if (!res.ok) process.exit(1);
}

run().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
