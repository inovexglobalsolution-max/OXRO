'use strict';
// Removes the smoke-test rows from Supabase (keeps seeds intact).
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
  if (!res.ok) throw new Error(JSON.stringify(j).slice(0, 300));
  return j;
}

async function main() {
  await q("delete from orders where customer_id='smoke-customer-1'");
  await q("delete from smart_change_transactions where customer_id='smoke-customer-1'");
  await q("delete from customers where customer_id='smoke-customer-1'");
  const c = await q(
    "select (select count(*) from customers) as customers, " +
      "(select count(*) from orders) as orders, " +
      "(select count(*) from restaurants) as restaurants, " +
      "(select count(*) from dishes) as dishes",
  );
  console.log('after cleanup:', JSON.stringify(c[0]));
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
