# OXRO DB/Backend Audit Report (READ-ONLY + safe ADD migration applied)

## Tables audited (18)
addresses, cart_lines, carts, coupons, customers, dineout_bookings, dishes, notifications, orders, pricing_audit, pricing_config, restaurants, reviews, search_recents, smart_change_transactions, support_tickets, wallet_transactions, wallets.

## REMOVE / NOT NEEDED (reported — NOT dropped; needs approval)
- addresses.name/phone duplicate recipient fields vs customers (keep; recipient snapshot)
- orders bill jsonb duplicates subtotal/delivery/discount/total (now also columns added)
- carts: no status (added)
- wallet_transactions: no type/status/wallet_id (added)
- smart_change: consent_status vs approval_status (added approval_status)
- notifications: unread bool vs read_at (added read_at)
- restaurants: missing address/phone/opening_hours/is_active (added)
- dishes: missing category_id/availability_status (added)
- dineout_bookings: missing date/time/customer_name/phone/status/updated_at (added)
- Backend: unused controllers authController.js, ordersController.js; resetForTests/setFailNextCredit test hooks; mock auth (scaffold).
- No backend minimum-order enforcement (only coupon min_order).

## ADD / REQUIRED (applied via migration, idempotent)
customers: profile_image_url, account_status, email_verified_at, phone_verified_at
addresses: state, landmark, latitude, longitude, address_type, is_default
orders: subtotal_paise, delivery_fee_paise, discount_paise, total_paise, delivery_address_snapshot
carts: status
cart_lines: cart_id, unit_price_paise, subtotal_paise
wallets: currency
wallet_transactions: wallet_id, transaction_type, transaction_status
smart_change_transactions: approval_status
notifications: read_at
restaurants: address, phone_number, opening_hours, is_active
dishes: category_id, availability_status
dineout_bookings: booking_date, booking_time, customer_name, customer_phone, booking_status, special_request, updated_at

## Backend files modified
- services/dineoutStore.js (accept/store new fields, return them)
- db/schema.sql (safe migration block)

## Minimum order amount
₹199 per-restaurant, enforced in Flutter only (restaurants/data/restaurant.dart:27 default; bag_screen.dart:70-71). Backend has no min-order validation → inconsistency. Reported, not changed.

## Dineout booking verification
Backend now stores customer_name/phone/date/time/status/special_request and returns them. Flutter unchanged (needs sync to send these fields).

## Tests
- backend: 34/34 pass
- flutter analyze: 0 issues

## Remaining
- Backend/Flutter full sync for new columns (dineout payload, wallet tx type, address state/lat/lng, etc.)
- Drop duplicate columns only after approval + data migration.
- Rotate leaked Render API key + GitHub PAT (manual).