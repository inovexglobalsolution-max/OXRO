import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';
import 'package:oxro/features/orders/presentation/screens/orders_screen.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(() {
    OrderStore.resetForTests();
    CartStore.resetForTests();
  });

  test('Active vs past buckets + reorder math', () {
    expect(OrderStore.instance.active.length, 2);
    expect(OrderStore.instance.past.length, 3);
    expect(
        OrderStore.instance.all
            .every((o) => o.products.isNotEmpty),
        isTrue);
    final n =
        OrderStore.instance.reorder('OXRO123456');
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
    OrderStore.instance
        .placeOrder(id: 'OXRO999001', products: snapshot);
    expect(OrderStore.instance.all.first.id, 'OXRO999001');
    expect(OrderStore.instance.active.length, 3);
    expect(OrderStore.instance.active.first.products.length,
        2);
    expect(OrderStore.instance.statusOf('OXRO999001'),
        OrderStatus.processing);
  });

  testWidgets('Orders tab shows active + past lists',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.byKey(const ValueKey('orders_active_list')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('orders_past_list')),
        findsOneWidget);
    expect(
        find.byKey(
            const ValueKey('order_card_OXRO123457')),
        findsOneWidget);
    expect(
        find.byKey(
            const ValueKey('order_card_OXRO123456')),
        findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const ValueKey('past_all_btn')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('past_all_btn')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Filter Past shows only past', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('orders_filter_2')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('orders_past_list')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('orders_active_list')),
        findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Reorder adds past items to bag', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    final btn = find.byKey(
        const ValueKey('reorder_OXRO123456'));
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(btn);
    await _settle(tester);
    expect(CartStore.instance.count, 2);
    expect(find.textContaining('Added back to Bag'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home Orders tab opens lists', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.text('Orders'));
    await _settle(tester);
    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('Past Orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Orders 320 + tablet no overflow',
      (tester) async {
    for (final size in [
      const Size(320, 568),
      const Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      OrderStore.resetForTests();
      await tester.pumpWidget(
          MaterialApp(home: OrdersScreen(onShopNow: () {})));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  test('Tracking steps per status + unknown fallback', () {
    OrderStore.resetForTests();
    final shipped =
        OrderStore.instance.trackingSteps('OXRO123457');
    expect(shipped.length, 5);
    expect(shipped.first.label, 'Order Placed');
    final delivered =
        OrderStore.instance.trackingSteps('OXRO123456');
    expect(
        delivered.last.time.contains('06:00 PM'), isTrue);
    // Unknown id → shipped mock timeline.
    final unknown =
        OrderStore.instance.trackingSteps('NOPE999');
    expect(unknown.length, 5);
    expect(OrderStore.instance.statusOf('NOPE999'),
        OrderStatus.shipped);
    expect(OrderStore.instance.etaFor('OXRO123456'),
        'Delivered');
    expect(OrderStore.instance.etaFor('OXRO123457'),
        contains('ETA'));
  });

  testWidgets('Tracking renders 5 nodes + ETA', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(const MaterialApp(
        home: TrackingScreen(orderId: 'OXRO123457')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('track_screen')),
        findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(ValueKey('track_node_$i')),
          findsOneWidget);
    }
    expect(find.text('Shipped'), findsWidgets);
    expect(find.byKey(const ValueKey('track_eta')),
        findsOneWidget);
    // Copy pill works.
    await tester.tap(find.byKey(const ValueKey('track_copy')));
    await _settle(tester);
    expect(find.textContaining('copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('19 Track button opens 18 tracking',
      (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
        MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    final btn = find.byKey(
        const ValueKey('track_btn_OXRO123457'));
    await tester.ensureVisible(btn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(btn);
    await _settle(tester);
    expect(find.byKey(const ValueKey('track_screen')),
        findsOneWidget);
    expect(find.text('Order ID: OXRO123457'),
        findsOneWidget);
    // Back pops to orders.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('My Orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tracking 320 + 390 no overflow',
      (tester) async {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844)
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      OrderStore.resetForTests();
      await tester.pumpWidget(const MaterialApp(
          home: TrackingScreen(orderId: 'OXRO123457')));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('20 details renders hero + items + bill',
      (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(const MaterialApp(
        home: OrderDetailsScreen(orderId: 'OXRO123457')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('details_screen')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('details_id')),
        findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('Delivery Address'), findsOneWidget);
    expect(find.text('Total Amount'), findsOneWidget);
    expect(find.byKey(const ValueKey('details_track')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('details_return')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('19 card tap opens 20 details → track',
      (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
        MaterialApp(home: OrdersScreen(onShopNow: () {})));
    await _settle(tester);

    // Tap the card body (top area, away from inner buttons).
    final card = find.byKey(
        const ValueKey('order_card_OXRO123457'));
    final rect = tester.getRect(card);
    await tester.tapAt(
        Offset(rect.center.dx, rect.top + 20));
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_screen')),
        findsOneWidget);

    await tester.tap(find.byKey(
        const ValueKey('details_track')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('track_screen')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Details 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    OrderStore.resetForTests();
    await tester.pumpWidget(const MaterialApp(
        home: OrderDetailsScreen(orderId: 'OXRO123457')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
