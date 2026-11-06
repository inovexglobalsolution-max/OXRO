'use strict';
// Read-only DB verification via Supabase Management API.
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const token = process.env.SUPABASE_ACCESS_TOKEN;
const ref = 'rmsrzsceuvbykcvoapet';

async function q(query) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${ref}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error(JSON.stringify(j).slice(0, 500));
  return j;
}

async function main() {
  const tables = await q(
    "select table_name from information_schema.tables where table_schema='public' order by table_name",
  );
  const names = tables.map((t) => t.table_name).filter(Boolean);
  console.log(`TABLES: ${names.length}`);
  console.log(names.join(', '));

  const rls = await q(
    "select relname, relrowsecurity from pg_class where relnamespace='public'::regnamespace and relkind='r' order by relname",
  );
  const withRls = rls.filter((r) => r.relrowsecurity).length;
  console.log(`RLS enabled: ${withRls}/${rls.length}`);

  const seeded = await q(
    'select (select count(*) from restaurants) as restaurants, (select count(*) from dishes) as dishes, (select count(*) from coupons) as coupons, (select count(*) from pricing_config) as pricing',
  );
  console.log('SEEDS:', JSON.stringify(seeded[0]));
}

main().catch((e) => {
  console.error('VERIFY FAILED:', e.message);
  process.exit(1);
});
