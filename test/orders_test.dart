import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/invoice_screen.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';
import 'package:oxro/features/orders/presentation/screens/orders_screen.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';
import 'package:oxro/features/premium/data/premium_store.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

const _food = Product(
  id: 77001,
  name: 'Paneer Bowl',
  brand: 'Green Bowl',
  restaurantId: 'R-FOOD',
  restaurantName: 'Green Bowl',
  price: 249,
  mrp: 299,
  rating: 4.3,
  reviews: 120,
  icon: Icons.rice_bowl,
  colors: [Colors.white, Colors.green],
);

const _otherFood = Product(
  id: 77002,
  name: 'Chicken Bowl',
  brand: 'Other Kitchen',
  restaurantId: 'R-OTHER',
  restaurantName: 'Other Kitchen',
  price: 299,
  mrp: 349,
  rating: 4.1,
  reviews: 90,
  icon: Icons.rice_bowl,
  colors: [Colors.white, Colors.orange],
);

void main() {
  setUp(() {
    OrderStore.resetForTests();
    CartStore.resetForTests();
    PremiumStore.resetForTests();
  });

  test('Active vs past buckets + reorder math', () {
    expect(OrderStore.instance.active.length, 2);
    expect(OrderStore.instance.past.length, 3);
    expect(OrderStore.instance.all.every((o) => o.products.isNotEmpty), isTrue);
    final n = OrderStore.instance.reorder('OXRO123456');
    expect(n, 2);
    expect(CartStore.instance.count, 2);
    expect(OrderStore.instance.reorder('NOPE'), 0);
  });

  test('placeOrder snapshots qty-expanded + tops active', () {
    OrderStore.resetForTests();
    CartStore.resetForTests();
    expect(OrderStore.instance.active.length, 2);
    final p = OrderStore.instance.all
        .firstWhere((o) => o.id == 'OXRO123457')
        .products
        .first;
    CartStore.instance.add(p);
    CartStore.instance.add(p);
    final snapshot = [
      for (final l in CartStore.instance.lines)
        for (var i = 0; i < l.qty; i++) l.product,
    ];
    expect(snapshot.length, 2);
    OrderStore.instance.placeOrder(id: 'OXRO999001', products: snapshot);
    expect(OrderStore.instance.all.first.id, 'OXRO999001');
    expect(OrderStore.instance.active.length, 3);
    expect(OrderStore.instance.active.first.products.length, 2);
    expect(OrderStore.instance.statusOf('OXRO999001'), OrderStatus.processing);
  });

  test('Seeded history is food-only with kitchens and bills', () {
    final o = OrderStore.instance.byId('OXRO123457')!;
    expect(o.kitchenName, 'Paradise Biryani');
    expect(o.restaurantId, 'r_paradise');
    expect(o.bill, isNotNull);
    expect(o.products.every((p) => p.restaurantId == 'r_paradise'), isTrue);
    expect(o.products.first.name, isNot(contains('Nike')));
    expect(o.payablePaise, greaterThan(o.total * 100));
  });

  test('Food order keeps kitchen and reorder rebinds the bag', () {
    OrderStore.instance.placeOrder(
      id: 'FOOD1',
      products: const [_food],
      restaurantId: 'R-FOOD',
      restaurantName: 'Green Bowl',
    );
    final order = OrderStore.instance.byId('FOOD1')!;
    expect(order.kitchenName, 'Green Bowl');
    expect(order.restaurantId, 'R-FOOD');
    expect(OrderStore.instance.etaFor('FOOD1'), contains('mins'));

    CartStore.instance.add(_otherFood);
    expect(CartStore.instance.restaurantId, 'R-OTHER');
    expect(OrderStore.instance.reorder('FOOD1'), 1);
    expect(CartStore.instance.count, 1);
    expect(CartStore.instance.restaurantId, 'R-FOOD');
    expect(CartStore.instance.restaurantName, 'Green Bowl');
  });

  test('Food order captures note + cutlery and cart clears them', () {
    CartStore.instance.add(_food);
    CartStore.instance.setInstructions('No onions');
    CartStore.instance.setCutlery(true);
    OrderStore.instance.placeOrder(
      id: 'FOOD2',
      products: const [_food],
      restaurantId: 'R-FOOD',
      restaurantName: 'Green Bowl',
      instructions: CartStore.instance.instructions,
      cutleryOptIn: CartStore.instance.cutleryOptIn,
    );
    final order = OrderStore.instance.byId('FOOD2')!;
    expect(order.instructions, 'No onions');
    expect(order.cutleryOptIn, isTrue);

    CartStore.instance.clear();
    expect(CartStore.instance.instructions, isEmpty);
    expect(CartStore.instance.cutleryOptIn, isFalse);
  });

  testWidgets('Food order card shows the kitchen', (tester) async {
    OrderStore.instance.placeOrder(
      id: 'FOOD1',
      products: const [_food],
      restaurantId: 'R-FOOD',
      restaurantName: 'Green Bowl',
    );
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    expect(find.byKey(const ValueKey('order_kitchen_FOOD1')), findsOneWidget);
    expect(find.text('Green Bowl'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('order_card_FOOD1')),
        matching: find.text('Order confirmed'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Invoice shows the kitchen and food bill', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: InvoiceScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Paradise Biryani'), findsOneWidget);
    expect(find.text('Restaurant packaging'), findsOneWidget);
    expect(find.text('Shipping Fee'), findsNothing);
    expect(find.text('Item total'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Invoice prints the kitchen note and cutlery choice', (
    tester,
  ) async {
    OrderStore.instance.placeOrder(
      id: 'NOTED1',
      products: const [_food],
      restaurantId: 'R-FOOD',
      restaurantName: 'Green Bowl',
      instructions: 'No onions',
      cutleryOptIn: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: InvoiceScreen(orderId: 'NOTED1')),
    );
    await _settle(tester);

    expect(find.text('Note'), findsOneWidget);
    expect(find.text('No onions'), findsOneWidget);
    expect(find.text('Cutlery'), findsOneWidget);
    expect(find.text('Not requested'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Orders tab shows active + past lists', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.byKey(const ValueKey('orders_active_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('orders_past_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('order_card_OXRO123457')), findsOneWidget);
    expect(find.byKey(const ValueKey('order_card_OXRO123456')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('past_all_btn')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('past_all_btn')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Filter Past shows only past', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('orders_filter_2')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('orders_past_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('orders_active_list')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Reorder adds past items to bag', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    final btn = find.byKey(const ValueKey('reorder_OXRO123456'));
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(btn);
    await _settle(tester);
    expect(CartStore.instance.count, 2);
    expect(find.textContaining('Added back to Bag'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  test('Terminal orders keep label ETA + no active tracking step', () {
    expect(OrderStore.instance.arrivalWindowFor('OXRO123456'), 'Delivered');
    expect(OrderStore.instance.etaFor('OXRO123456'), 'Delivered');

    OrderStore.instance.injectForTests(
      const MockOrder(
        id: 'CANCEL1',
        date: 'Today',
        status: OrderStatus.cancelled,
        products: [_food],
        restaurantId: 'R-FOOD',
        restaurantName: 'Green Bowl',
      ),
    );
    expect(OrderStore.instance.arrivalWindowFor('CANCEL1'), 'Cancelled');
    expect(OrderStore.instance.etaFor('CANCEL1'), 'Cancelled');
    expect(
      OrderStore.instance
          .trackingSteps('CANCEL1')
          .where((s) => s.time == 'now'),
      isEmpty,
    );
  });

  testWidgets('Cancelled tracking shows terminal state without pulse', (
    tester,
  ) async {
    OrderStore.instance.injectForTests(
      const MockOrder(
        id: 'CANCEL1',
        date: 'Today',
        status: OrderStatus.cancelled,
        products: [_food],
        restaurantId: 'R-FOOD',
        restaurantName: 'Green Bowl',
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'CANCEL1')),
    );
    await _settle(tester);

    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('now'), findsNothing);
    expect(find.textContaining('Arriving by'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Reorder from another kitchen asks before replacing', (
    tester,
  ) async {
    CartStore.instance.add(_otherFood);
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(onShopNow: () {}, onBag: () {}),
      ),
    );
    await _settle(tester);

    final btn = find.byKey(const ValueKey('reorder_OXRO123456'));
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(btn);
    await _settle(tester);

    expect(find.text('Replace bag?'), findsOneWidget);
    expect(find.byKey(const ValueKey('reorder_replace_no')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reorder_replace_no')));
    await _settle(tester);
    expect(CartStore.instance.restaurantId, 'R-OTHER');

    await tester.tap(btn);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('reorder_replace_yes')));
    await _settle(tester);
    expect(CartStore.instance.restaurantId, 'r_dominos');
    expect(find.textContaining('Added back to Bag'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Order card shows amount paid from the bill', (tester) async {
    final order = OrderStore.instance.byId('OXRO123456')!;
    expect(order.payablePaise, greaterThan(order.total * 100));
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('order_card_OXRO123456')),
        matching: find.textContaining(Money.inr(order.payablePaise)),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Orders opens from Account menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_orders')));
    await _settle(tester);
    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('Past Orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Orders 320 + tablet no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(768, 1024)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      OrderStore.resetForTests();
      await tester.pumpWidget(
        MaterialApp(home: OrdersScreen(onShopNow: () {})),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  test('Tracking steps per status + unknown fallback', () {
    OrderStore.resetForTests();
    final shipped = OrderStore.instance.trackingSteps('OXRO123457');
    expect(shipped.length, 5);
    expect(shipped.first.label, 'Order Placed');
    final delivered = OrderStore.instance.trackingSteps('OXRO123456');
    expect(delivered.last.time.contains('11:10 AM'), isTrue);
    // Unknown id → shipped mock timeline.
    final unknown = OrderStore.instance.trackingSteps('NOPE999');
    expect(unknown.length, 5);
    expect(OrderStore.instance.statusOf('NOPE999'), OrderStatus.shipped);
    expect(OrderStore.instance.etaFor('OXRO123456'), 'Delivered');
    expect(OrderStore.instance.etaFor('OXRO123457'), contains('ETA'));
  });

  testWidgets('Tracking renders 5 nodes + ETA', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('track_screen')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('track_node_$i')), findsOneWidget);
    }
    expect(find.textContaining('Preparing'), findsWidgets);
    expect(find.byKey(const ValueKey('track_eta')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_journey')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_promo_carousel')), findsOneWidget);
    expect(find.text('OXRO Spotlight'), findsOneWidget);
    expect(find.text('Order #123457'), findsOneWidget);
    // Copy pill works.
    await tester.tap(find.byKey(const ValueKey('track_copy')));
    await _settle(tester);
    expect(find.textContaining('copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tracking header collapses into live status', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('track_status')), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('track_screen')),
      const Offset(0, -220),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('track_status')), findsOneWidget);
    expect(find.textContaining('Mins left'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tracking Help and View order navigate', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('track_help')));
    await _settle(tester);
    expect(find.byType(HelpScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);

    final view = find.byKey(const ValueKey('track_view_order'));
    await Scrollable.ensureVisible(tester.element(view), alignment: 0.5);
    await _settle(tester);
    await tester.tap(view);
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tracking promo opens PREMIUM', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    final promo = find.byKey(const ValueKey('track_promo_0'));
    await tester.ensureVisible(promo);
    await _settle(tester);
    await tester.tap(promo);
    await _settle(tester);
    expect(find.byKey(const ValueKey('premium_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('19 Track button opens 18 tracking', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    final btn = find.byKey(const ValueKey('track_btn_OXRO123457'));
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(btn);
    await _settle(tester);
    expect(find.byKey(const ValueKey('track_screen')), findsOneWidget);
    expect(find.text('Order #123457'), findsOneWidget);
    expect(find.byKey(const ValueKey('track_help')), findsOneWidget);
    // Back pops to orders.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('My Orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tracking 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      OrderStore.resetForTests();
      await tester.pumpWidget(
        const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('20 details renders hero + items + bill', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: OrderDetailsScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('details_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('details_id')), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('Delivery Address'), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.byKey(const ValueKey('details_track')), findsOneWidget);
    expect(find.byKey(const ValueKey('details_return')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('19 card tap opens 20 details → track', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    // Tap the card body (top area, away from inner buttons).
    final card = find.byKey(const ValueKey('order_card_OXRO123457'));
    final rect = tester.getRect(card);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 20));
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_screen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('details_track')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('track_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('20 details PREMIUM ad dismisses', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: OrderDetailsScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    final banner = find.byKey(const ValueKey('details_ad_banner'));
    await tester.ensureVisible(banner);
    await _settle(tester);
    expect(banner, findsOneWidget);
    expect(find.text('FREE DELIVERY'), findsOneWidget);
    expect(find.text('On every order above ₹199.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('details_ad_dismiss')));
    await _settle(tester);
    expect(banner, findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('20 details PREMIUM ad opens membership', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: OrderDetailsScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);

    final cta = find.byKey(const ValueKey('details_ad_cta'));
    await tester.ensureVisible(cta);
    await _settle(tester);
    await tester.tap(cta);
    await _settle(tester);
    expect(find.byKey(const ValueKey('premium_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Details 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    OrderStore.resetForTests();
    await tester.pumpWidget(
      const MaterialApp(home: OrderDetailsScreen(orderId: 'OXRO123457')),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const ValueKey('details_screen')),
      const Offset(0, -1200),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_ad_banner')), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
