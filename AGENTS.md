# AGENTS.md — OXRO (Flutter food delivery)

## Reply style
- Reply in **Tanglish** (Tamil + English mix). Keep it short and fast — user says "make it fast bro".

## Workflow (run after EVERY task, in order)
1. `flutter analyze` — must be **0 issues** (warnings count as failures).
2. `dart format <touched files>` — keep formatting clean.
3. `flutter test` — full suite must be **All tests passed**.
- Loop until all three are green before saying the task is done.

## Rules
- **Tests at HEAD are the spec.** When uncommitted WIP breaks a HEAD test, fix `lib/` — don't edit tests (exception: only when the test itself is wrong and that's confirmed).
- Never commit unless explicitly asked.

## Stack
- Flutter/Dart, Material, feature-first layout under `lib/features/*` (home, bag, checkout, orders, restaurant…).
- Shared data helpers in `lib/app/` (e.g. `app/data/delivery_schedule.dart`).
- Tests in `test/*_test.dart`, pump `MaterialApp(home: …)`, use `ValueKey(...)` + `find.byKey` heavily.

## Gotchas (learned the hard way)
- Schedule chip labels: `DeliverySlot.chipLabel => '$dayLabel · $slot'` (middle dot `·`, en-dash `–` in slots). Tests match this exact format — use `chipLabel`, never `'$day • $time'`.
- `MediaQuery.disableAnimationsOf(context)` is the API (not `MediaQuery.disableAnimations`).
- Cuisine strip sizing lives in `food_home_tab.dart` `_categoryRail`: `budgetWidth` must match `_Under250Tile`'s real width (48). Row order = BestOffers → Expanded cuisines → Under250 (Under250 hugs the right edge, `home_test.dart` asserts it sits right of the last cuisine).
- Bag per-line schedule chip: `_LineScheduleChip(line: line)` inside `_BagLineCard`, gated by `p.restaurantId != null`. Empty-bag guards: never call `store.lines.first` in build — StateError crashes tests.
- Active test order fixture `OXRO123457` has status `OrderStatus.shipped`.
- **Collapsible bill rows:** both bags (`bag_bill_toggle` in `BagBillCard`) and checkout (`checkout_bill_toggle` in `_summaryCard`) start **collapsed** (`_open`/`_billOpen = false`) and expand via `AnimatedSize(220ms)`. Any test asserting bill row text (`Small cart fee`, `Platform fee`, `GST (govt. taxes)`, `Delivery partner fee`, tips…) must tap the toggle first — use the `_expandBill(tester)` helper in `checkout_test.dart` / `pricing_test.dart`. Header (`Bill Summary` + item pill) and the **To pay** footer always stay visible.
- Premium cream cards: `OxroColors.premiumCream` bg + `premiumChampagne` border + gold pulse — see `_restaurantDetailsCard` (tracking) for the `_ambient` shadow-breathing pattern; always gate with `MediaQuery.disableAnimationsOf(context)` (reduce → static `pulse = 0.5`).
- Wallet screen title is **"OXRO Money"** (renamed from "OXRO Wallet" — header + profile menu label + `wallet_test.dart` expects).
