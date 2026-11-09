-- OXRO Supabase schema (run in SQL Editor — idempotent, safe to re-run)
-- Access: backend only via SUPABASE_SECRET_KEY (service role bypasses RLS).
-- No anon/authenticated policies on purpose → Flutter never talks to Supabase.

-- ============================================================ customers
create table if not exists customers (
  customer_id text primary key,
  name text,
  email text,
  phone text,
  default_address_id text,
  food_preference_enabled boolean not null default false,
  food_preference text,
  premium_member boolean not null default false,
  premium_joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================ addresses
create table if not exists addresses (
  id text primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  label text not null default 'Home',
  name text not null default '',
  phone text not null default '',
  line text not null default '',
  city text not null default '',
  pin text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_addresses_customer on addresses (customer_id);

-- ============================================================ carts
create table if not exists carts (
  customer_id text primary key references customers (customer_id) on delete cascade,
  instructions text not null default '',
  cutlery_opt_in boolean not null default false,
  restaurant_id text,
  restaurant_name text,
  updated_at timestamptz not null default now()
);

create table if not exists cart_lines (
  id bigint generated always as identity primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  line_key text not null,
  product_id text not null,
  product jsonb not null,
  qty integer not null check (qty > 0),
  size text,
  schedule jsonb,
  updated_at timestamptz not null default now(),
  unique (customer_id, line_key)
);
create index if not exists idx_cart_lines_customer on cart_lines (customer_id);

-- ============================================================ orders
create table if not exists orders (
  id text primary key,
  customer_id text not null references customers (customer_id),
  date text not null default 'Today',
  status text not null
    check (status in ('processing', 'shipped', 'outForDelivery', 'delivered', 'cancelled')),
  products jsonb not null,
  restaurant_id text,
  restaurant_name text,
  instructions text,
  cutlery_opt_in boolean,
  delivered_at timestamptz,
  bill jsonb not null,
  payment_method text check (payment_method in ('upi', 'card', 'wallet', 'cod')),
  payment_status text check (payment_status in ('paid', 'pending')),
  smart_change_txn_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_orders_customer_created on orders (customer_id, created_at desc);
create index if not exists idx_orders_status on orders (status);

-- ============================================================ wallets
create table if not exists wallets (
  customer_id text primary key references customers (customer_id) on delete cascade,
  balance_paise integer not null default 0 check (balance_paise >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists wallet_transactions (
  id text primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  label text not null,
  amount_paise integer not null,
  order_id text,
  created_at timestamptz not null default now()
);
create index if not exists idx_wallet_tx_customer on wallet_transactions (customer_id, created_at desc);

-- ============================================================ smart change
create table if not exists smart_change_transactions (
  txn_id text primary key,
  order_id text,
  customer_id text not null,
  partner_id text,
  order_amount_paise integer not null,
  declared_cash_paise integer not null,
  actual_cash_paise integer,
  remaining_change_paise integer not null,
  consent_status text not null default 'granted',
  wallet_transaction_id text,
  transaction_status text not null check (
    transaction_status in (
      'activated', 'order_linked', 'collected', 'credited', 'credit_pending', 'cancelled'
    )
  ),
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- One Smart Change transaction per order (mirrors in-memory appliedOrderIds).
create unique index if not exists uq_sc_order
  on smart_change_transactions (order_id) where order_id is not null;
create index if not exists idx_sc_status on smart_change_transactions (transaction_status);
create index if not exists idx_sc_customer on smart_change_transactions (customer_id);

-- ============================================================ pricing
create table if not exists pricing_config (
  id smallint primary key default 1 check (id = 1),
  config jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists pricing_audit (
  id bigint generated always as identity primary key,
  version integer not null,
  summary text not null,
  created_at timestamptz not null default now()
);

-- ============================================================ wishlist
create table if not exists wishlists (
  customer_id text not null references customers (customer_id) on delete cascade,
  product_id integer not null,
  product jsonb not null,
  created_at timestamptz not null default now(),
  primary key (customer_id, product_id)
);

-- ============================================================ reviews
create table if not exists reviews (
  id text primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  product_id integer not null,
  rating integer not null check (rating between 1 and 5),
  body text not null default '',
  photos jsonb not null default '[]'::jsonb,
  has_video boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, product_id)
);
create index if not exists idx_reviews_product on reviews (product_id);

-- ============================================================ support
create table if not exists support_tickets (
  id text primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  source text not null check (source in ('order', 'bag')),
  category_id text not null,
  category_label text not null,
  order_id text,
  restaurant_name text,
  items jsonb not null default '[]'::jsonb,
  note text not null default '',
  status text not null default 'Submitted',
  created_at timestamptz not null default now()
);
create index if not exists idx_support_customer on support_tickets (customer_id, created_at desc);

-- ============================================================ notifications
create table if not exists notifications (
  id text primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  title text not null,
  sub text not null,
  kind text not null check (kind in ('order', 'offer')),
  icon integer not null,
  time text not null,
  unread boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_notifications_customer on notifications (customer_id, created_at desc);

-- ============================================================ search recents
create table if not exists search_recents (
  customer_id text not null references customers (customer_id) on delete cascade,
  query text not null,
  created_at timestamptz not null default now(),
  primary key (customer_id, query)
);

-- ============================================================ coupons
create table if not exists coupons (
  code text primary key,
  title text not null,
  sub text not null,
  off integer not null default 0,
  percent boolean not null default false,
  cap integer not null default 0,
  min_order integer not null default 0,
  free_ship boolean not null default false,
  active boolean not null default true
);

-- ============================================================ catalogue
create table if not exists restaurants (
  id text primary key,
  name text not null,
  cuisines text[] not null default '{}',
  rating real not null default 0,
  reviews integer not null default 0,
  distance_label text not null default '',
  eta_minutes integer not null default 0
);

create table if not exists dishes (
  id integer primary key,
  restaurant_id text not null references restaurants (id) on delete cascade,
  name text not null,
  brand text not null,
  price integer not null check (price >= 0),
  mrp integer not null check (mrp >= 0),
  rating real not null default 4.3,
  reviews integer not null default 120,
  icon bigint not null default 58732,
  colors bigint[] not null default '{4294967295,4294928896}',
  veg boolean not null default false,
  egg boolean not null default false,
  description text not null default '',
  image_url text
);
create index if not exists idx_dishes_restaurant on dishes (restaurant_id);
create index if not exists idx_dishes_name on dishes (name);

-- ============================================================ dineout bookings
create table if not exists dineout_bookings (
  id text primary key,
  customer_id text not null references customers (customer_id) on delete cascade,
  restaurant_id text not null,
  guests integer not null check (guests > 0),
  slot text not null,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists idx_dineout_customer on dineout_bookings (customer_id, created_at desc);

-- ============================================================ RLS
-- Deny-all for anon/authenticated: only the backend (service role) reads/writes.
-- Flutter never contacts Supabase directly.
alter table customers enable row level security;
alter table addresses enable row level security;
alter table carts enable row level security;
alter table cart_lines enable row level security;
alter table orders enable row level security;
alter table wallets enable row level security;
alter table wallet_transactions enable row level security;
alter table smart_change_transactions enable row level security;
alter table pricing_config enable row level security;
alter table pricing_audit enable row level security;
alter table wishlists enable row level security;
alter table reviews enable row level security;
alter table support_tickets enable row level security;
alter table notifications enable row level security;
alter table search_recents enable row level security;
alter table coupons enable row level security;
alter table restaurants enable row level security;
alter table dishes enable row level security;
alter table dineout_bookings enable row level security;

-- ============================================================ seeds (idempotent)
insert into pricing_config (id, config) values (1, '{
  "version": 1,
  "effectiveFromIso": "2026-01-01T00:00:00Z",
  "commissionBps": 500,
  "platformFeePaise": 700,
  "customerDeliveryFeePaise": 4000,
  "customerPackagingFeePaise": 0,
  "customerGstBps": 500,
  "commissionGstBps": 1800,
  "tdsBps": 100,
  "basePayoutPaise": 2500,
  "includedDistanceMetres": 3000,
  "perKmPaise": 700,
  "stackingBonusPaise": 0,
  "freeWaitingMinutes": 5,
  "waitingCompPerMinutePaise": 0,
  "peakWindows": [],
  "specialIncentives": []
}'::jsonb)
on conflict (id) do nothing;

insert into coupons (code, title, sub, off, percent, cap, min_order, free_ship) values
  ('OXRO500', 'Flat Rs.500 OFF', 'On orders above Rs.2,999', 500, false, 0, 2999, false),
  ('WELCOME10', '10% OFF up to Rs.300', 'On orders above Rs.999', 10, true, 300, 999, false),
  ('FEST200', 'Flat Rs.200 OFF', 'On orders above Rs.1,499', 200, false, 0, 1499, false),
  ('FREESHIP', 'Free Delivery', 'No shipping fee above Rs.499', 0, false, 0, 499, true)
on conflict (code) do nothing;

insert into restaurants (id, name, cuisines, rating, reviews, distance_label, eta_minutes) values
  ('r_paradise', 'Paradise Biryani', '{Biryani,Hyderabadi}', 4.5, 3200, '2.1 km', 30),
  ('r_saravana', 'Saravana Bhavan', '{South Indian,Vegetarian}', 4.4, 5100, '1.4 km', 25),
  ('r_dominos', 'Domino''s Pizza', '{Pizza,Fast Food}', 4.2, 8400, '3.2 km', 35),
  ('r_bbq', 'BBQ Nation', '{Barbecue,North Indian}', 4.6, 2600, '4.0 km', 45),
  ('r_a2b', 'A2B Veg', '{South Indian,Sweets}', 4.3, 1900, '2.8 km', 30),
  ('r_momo_hut', 'Momo Hut', '{Chinese,Momos}', 4.1, 1400, '1.9 km', 28),
  ('r_cake_corner', 'Cake Corner', '{Desserts,Bakery}', 4.4, 1100, '2.5 km', 32)
on conflict (id) do nothing;

insert into dishes (id, restaurant_id, name, brand, price, mrp, rating, reviews, icon, colors, veg, description) values
  (900001, 'r_paradise', 'Hyderabadi Chicken Biryani', 'Paradise Biryani', 249, 299, 4.3, 980, 58732, '{4294967295,4294928896}', false, ''),
  (900002, 'r_paradise', 'Mutton Dum Biryani', 'Paradise Biryani', 329, 399, 4.3, 640, 58732, '{4294967295,4294928896}', false, ''),
  (900003, 'r_paradise', 'Veg Dum Biryani', 'Paradise Biryani', 199, 249, 4.3, 410, 58732, '{4294967295,4294928896}', true, ''),
  (900011, 'r_saravana', 'Ghee Roast Dosa', 'Saravana Bhavan', 89, 110, 4.3, 1500, 58732, '{4294967295,4281236815}', true, ''),
  (900012, 'r_saravana', 'Masala Dosa', 'Saravana Bhavan', 79, 99, 4.3, 1320, 58732, '{4294967295,4281236815}', true, ''),
  (900013, 'r_saravana', 'Idli Vada Combo', 'Saravana Bhavan', 69, 85, 4.3, 890, 58732, '{4294967295,4281236815}', true, ''),
  (900021, 'r_dominos', 'Margherita Pizza', 'Domino''s Pizza', 219, 269, 4.3, 2100, 58732, '{4294967295,4294928896}', true, ''),
  (900022, 'r_dominos', 'Peppy Paneer Pizza', 'Domino''s Pizza', 299, 359, 4.3, 1200, 58732, '{4294967295,4294928896}', true, ''),
  (900023, 'r_dominos', 'Chicken Dominator Pizza', 'Domino''s Pizza', 399, 469, 4.3, 980, 58732, '{4294967295,4294928896}', false, ''),
  (900031, 'r_bbq', 'Chicken Tikka Platter', 'BBQ Nation', 349, 429, 4.3, 760, 58732, '{4294967295,4294928896}', false, ''),
  (900032, 'r_bbq', 'Paneer Tikka Platter', 'BBQ Nation', 299, 369, 4.3, 520, 58732, '{4294967295,4294928896}', true, ''),
  (900033, 'r_bbq', 'Mutton Seekh Kebab', 'BBQ Nation', 399, 479, 4.3, 430, 58732, '{4294967295,4294928896}', false, ''),
  (900041, 'r_a2b', 'Pongal', 'A2B Veg', 79, 99, 4.3, 120, 58732, '{4294967295,4281236815}', true, ''),
  (900042, 'r_a2b', 'Rava Kesari', 'A2B Veg', 59, 75, 4.3, 120, 58732, '{4294967295,4281236815}', true, ''),
  (900051, 'r_momo_hut', 'Steamed Chicken Momos', 'Momo Hut', 149, 189, 4.3, 600, 58732, '{4294967295,4294928896}', false, ''),
  (900052, 'r_momo_hut', 'Veg Fried Momos', 'Momo Hut', 129, 169, 4.3, 480, 58732, '{4294967295,4294928896}', true, ''),
  (900061, 'r_cake_corner', 'Chocolate Truffle Cake', 'Cake Corner', 449, 549, 4.3, 120, 58732, '{4294967295,4294928896}', true, ''),
  (900062, 'r_cake_corner', 'Red Velvet Pastry', 'Cake Corner', 129, 159, 4.3, 120, 58732, '{4294967295,4294928896}', true, '')
on conflict (id) do nothing;


-- ============================================================ SAFE MIGRATION: ADD missing columns (idempotent, non-destructive)
-- Adds only genuinely-missing fields. Existing data preserved. No drops.

-- customers
alter table customers add column if not exists profile_image_url text;
alter table customers add column if not exists account_status text not null default 'active';
alter table customers add column if not exists email_verified_at timestamptz;
alter table customers add column if not exists phone_verified_at timestamptz;

-- addresses
alter table addresses add column if not exists state text not null default '';
alter table addresses add column if not exists landmark text not null default '';
alter table addresses add column if not exists latitude double precision;
alter table addresses add column if not exists longitude double precision;
alter table addresses add column if not exists address_type text not null default 'home';
alter table addresses add column if not exists is_default boolean not null default false;

-- orders
alter table orders add column if not exists subtotal_paise integer;
alter table orders add column if not exists delivery_fee_paise integer;
alter table orders add column if not exists discount_paise integer;
alter table orders add column if not exists total_paise integer;
alter table orders add column if not exists delivery_address_snapshot jsonb;

-- carts
alter table carts add column if not exists status text not null default 'active';

-- cart_lines
alter table cart_lines add column if not exists cart_id text;
alter table cart_lines add column if not exists unit_price_paise integer;
alter table cart_lines add column if not exists subtotal_paise integer;

-- wallets
alter table wallets add column if not exists currency text not null default 'INR';

-- wallet_transactions
alter table wallet_transactions add column if not exists wallet_id text;
alter table wallet_transactions add column if not exists transaction_type text;
alter table wallet_transactions add column if not exists transaction_status text not null default 'completed';

-- smart_change_transactions
alter table smart_change_transactions add column if not exists approval_status text not null default 'granted';

-- notifications
alter table notifications add column if not exists read_at timestamptz;

-- restaurants
alter table restaurants add column if not exists address text not null default '';
alter table restaurants add column if not exists phone_number text not null default '';
alter table restaurants add column if not exists opening_hours text not null default '';
alter table restaurants add column if not exists is_active boolean not null default true;

-- dishes
alter table dishes add column if not exists category_id text;
alter table dishes add column if not exists availability_status text not null default 'available';

-- dineout_bookings
alter table dineout_bookings add column if not exists booking_date date;
alter table dineout_bookings add column if not exists booking_time time;
alter table dineout_bookings add column if not exists customer_name text not null default '';
alter table dineout_bookings add column if not exists customer_phone text not null default '';
alter table dineout_bookings add column if not exists booking_status text not null default 'confirmed';
alter table dineout_bookings add column if not exists special_request text;
alter table dineout_bookings add column if not exists updated_at timestamptz not null default now();
-- Reservation platform fee payment (₹7.00) — required for confirmation.
alter table dineout_bookings add column if not exists payment_id text unique;
alter table dineout_bookings add column if not exists payment_status text not null default 'pending';
alter table dineout_bookings add column if not exists amount_paise integer;

-- orders pricing breakdown
alter table orders add column if not exists small_cart_fee_paise integer;
alter table orders add column if not exists tax_paise integer;
alter table orders add column if not exists free_delivery_applied boolean not null default false;


-- ============================================================ support tickets v2 (chatbot phase 1)
alter table support_tickets add column if not exists role text not null default 'customer';
alter table support_tickets add column if not exists priority text not null default 'normal';
alter table support_tickets add column if not exists assigned_team text;
alter table support_tickets add column if not exists updated_at timestamptz not null default now();
alter table support_tickets add column if not exists resolution_notes text;

-- ============================================================ delivery partners
alter table orders add column if not exists delivery_partner_id text;

create table if not exists delivery_partners (
  id text primary key,
  name text not null,
  phone text,
  photo_url text,
  rating numeric(3,1) default 4.5,
  completed_deliveries integer not null default 0,
  vehicle_type text,
  vehicle_number text,
  verified boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_delivery_partners_verified on delivery_partners (verified);
alter table delivery_partners enable row level security;

create table if not exists delivery_partner_locations (
  partner_id text primary key references delivery_partners (id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  updated_at timestamptz not null default now()
);
alter table delivery_partner_locations enable row level security;

create table if not exists order_delivery_assignments (
  order_id text primary key references orders (id) on delete cascade,
  partner_id text not null references delivery_partners (id),
  assigned_at timestamptz not null default now(),
  picked_up_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_assignments_partner on order_delivery_assignments (partner_id);
alter table order_delivery_assignments enable row level security;

create table if not exists order_messages (
  id text primary key,
  order_id text not null references orders (id) on delete cascade,
  sender_role text not null check (sender_role in ('customer', 'partner')),
  body text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_order_messages_order on order_messages (order_id, created_at asc);
alter table order_messages enable row level security;

-- Seed one verified demo partner (un-assigned) so the app can render a real
-- driver once ops assigns an order to them. Never auto-assigned in code.
insert into delivery_partners (id, name, phone, rating, completed_deliveries, vehicle_type, vehicle_number, verified) values
  ('DP001', 'Rahul Kumar', '9876543210', 4.8, 1243, 'Motorcycle', 'TN 09 AB 1234', true)
on conflict (id) do nothing;

-- ============================================================ knowledge base / FAQs
create table if not exists faqs (
  id text primary key,
  role text not null default 'customer' check (role in ('customer', 'restaurant', 'delivery')),
  category text not null default 'general',
  question text not null,
  answer text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_faqs_role_active on faqs (role, active);
alter table faqs enable row level security;

insert into faqs (id, role, category, question, answer) values
  ('faq_c_order_track', 'customer', 'orders', 'How do I track my order?', 'Open Orders from the Account menu to see live status and delivery progress.'),
  ('faq_c_refund', 'customer', 'payments', 'How do refunds work?', 'Eligible refunds are returned to the original payment method; timing depends on your bank or payment provider.'),
  ('faq_c_fees', 'customer', 'payments', 'What is the small cart fee?', 'A small cart fee applies below Rs 99 of eligible cart value and is shown separately at checkout.'),
  ('faq_r_onboard', 'restaurant', 'onboarding', 'How do I register my restaurant?', 'Partner onboarding starts with KYC and FSSAI document upload; our team verifies before activation.'),
  ('faq_r_payout', 'restaurant', 'finance', 'When do I get my settlement?', 'Settlements follow your configured payout cycle after deducting applicable commission.'),
  ('faq_d_earn', 'delivery', 'earnings', 'How are delivery earnings calculated?', 'Earnings include distance-based payout plus any eligible incentives and customer tips.'),
  ('faq_d_docs', 'delivery', 'onboarding', 'Which documents are needed?', 'A valid driving licence, vehicle documents and bank details are required for verification.')
on conflict (id) do nothing;
