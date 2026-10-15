import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';

const _p1 = Product(
  id: 101,
  name: 'Test Shirt',
  brand: 'OXRO',
  price: 799,
  mrp: 999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);
const _p2 = Product(
  id: 102,
  name: 'Test Shoes',
  brand: 'Nike',
  price: 1999,
  mrp: 2999,
  rating: 4.5,
  reviews: 200,
  icon: Icons.directions_run,
  colors: [Colors.white, Colors.black],
);

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(CartStore.resetForTests);

  // ---- Store unit tests ----
  test('Cart add/qty/totals/remove/clear', () {
    final cart = CartStore.instance;
    expect(cart.count, 0);
    expect(cart.contains(101), isFalse);

    cart.add(_p1);
    expect(cart.qty(101), 1);
    expect(cart.count, 1);
    expect(cart.distinct, 1);

    cart.add(_p1);
    cart.add(_p2);
    expect(cart.qty(101), 2);
    expect(cart.count, 3);
    expect(cart.distinct, 2);
    expect(cart.totalPrice, 799 * 2 + 1999);
    expect(cart.totalMrp, 999 * 2 + 2999);
    expect(cart.savings, cart.totalMrp - cart.totalPrice);

    cart.increment(102);
    expect(cart.qty(102), 2);
    cart.decrement(102);
    expect(cart.qty(102), 1);
    cart.decrement(102);
    expect(cart.contains(102), isFalse);

    cart.remove(101);
    expect(cart.count, 0);
    cart.add(_p1);
    cart.clear();
    expect(cart.count, 0);
    expect(cart.lines, isEmpty);
  });

  test('Cart notifies listeners', () {
    final cart = CartStore.instance;
    var calls = 0;
    void listener() => calls++;
    cart.addListener(listener);
    cart.add(_p1);
    cart.increment(101);
    cart.decrement(101);
    cart.remove(999); // no-op, no notify
    cart.clear();
    expect(calls, 4);
    cart.removeListener(listener);
  });

  // ---- Widget tests ----
  testWidgets('PLP card ADD morphs to stepper and back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ProductListingScreen(
      title: 'T',
      leafs: const ['Shirts'],
      icon: Icons.checkroom_outlined,
    )));
    await _frames(tester);

    final before = find.text('ADD').evaluate().length;
    expect(before, greaterThan(0));
    await tester.tap(find.text('ADD').first);
    await tester.pump(const Duration(milliseconds: 300));
    // One card flipped to stepper, rest still ADD.
    expect(CartStore.instance.count, 1);
    expect(find.text('ADD').evaluate().length, before - 1);
    expect(find.text('+'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Stepper + and - change qty', (tester) async {
    // Tall viewport: deal cards need no scrolling (avoids
    // ensureVisible over-scrolling the horizontal deals list).
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // First deal card is Nike Air Max (id 1).
    final firstAdd = find.text('ADD').first;
    await tester.ensureVisible(firstAdd);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(firstAdd);
    await tester.pump(const Duration(milliseconds: 300));
    expect(CartStore.instance.count, 1);

    // Stepper + increments.
    await tester.tap(find.byKey(const ValueKey('inc_1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(CartStore.instance.count, 2);

    // Stepper - twice removes line (back to ADD).
    await tester.tap(find.byKey(const ValueKey('dec_1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('dec_1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(CartStore.instance.count, 0);
    expect(find.text('ADD'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bag badge follows cart count', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Empty cart → no badge.
    expect(find.byKey(const ValueKey('bag_badge_count')),
        findsNothing);

    final add = find.text('ADD').first;
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 300));
    // Header badge + center Bag tab badge both show.
    expect(find.byKey(const ValueKey('bag_badge_count')),
        findsWidgets);
    expect(
        (tester.widgetList(find.byKey(
                    const ValueKey('bag_badge_count')))
                .first as Text)
            .data,
        '1');

    await tester.tap(find.text('+').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    // Switcher pop settles: every badge shows the live count.
    expect(
        tester
            .widgetList(find.byKey(
                const ValueKey('bag_badge_count')))
            .map((w) => (w as Text).data)
            .toSet(),
        {'2'});
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('AddButton standalone shows ADD then stepper',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AddButton(product: _p1))));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('ADD'), findsOneWidget);
    await tester.tap(find.text('ADD'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('1'), findsOneWidget);
    expect(CartStore.instance.qty(101), 1);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Floating cart bar hides empty, shows + goes to Bag',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Empty bag → bar hidden.
    expect(find.byKey(const ValueKey('cart_bar')),
        findsNothing);

    final firstAdd = find.text('ADD').first;
    await tester.ensureVisible(firstAdd);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(firstAdd);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('cart_bar')),
        findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('cart_bar_go')),
        findsOneWidget);

    // Proceed → Bag tab (center).
    await tester
        .tap(find.byKey(const ValueKey('cart_bar_go')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Shopping Bag'), findsOneWidget);
    // Bar hides off the Home tab.
    expect(find.byKey(const ValueKey('cart_bar')),
        findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
