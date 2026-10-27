import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

const _tee = Product(
  id: 9101,
  name: 'Nav Tee',
  brand: 'OXRO',
  price: 499,
  mrp: 699,
  rating: 4.5,
  reviews: 120,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  testWidgets('Delivery, raised cart, and dining form a 3-item nav', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    double cx(String key) => tester.getCenter(find.byKey(ValueKey(key))).dx;

    final delivery = cx('nav_delivery');
    final cart = cx('nav_cart');
    final dining = cx('nav_dining');
    expect(delivery, lessThan(cart));
    expect(cart, lessThan(dining));
    expect(
      cart,
      closeTo(tester.getCenter(find.byKey(const ValueKey('nav_bar'))).dx, 1),
    );

    expect(find.byKey(const ValueKey('nav_under250')), findsNothing);
    expect(find.text('Under ₹250'), findsNothing);

    final barTop = tester.getTopLeft(find.byKey(const ValueKey('nav_bar'))).dy;
    final cartTop = tester
        .getTopLeft(find.byKey(const ValueKey('nav_cart_button')))
        .dy;
    expect(
      cartTop,
      lessThan(barTop - 8),
      reason: 'cart button should lift above the bar',
    );

    final deliveryIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('nav_delivery')),
        matching: find.byIcon(Icons.delivery_dining_rounded),
      ),
    );
    final diningIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('nav_dining')),
        matching: find.byIcon(Icons.restaurant_rounded),
      ),
    );
    expect(deliveryIcon.size, 18);
    expect(diningIcon.size, 18);
    expect(
      tester.getSize(find.byKey(const ValueKey('nav_cart_button'))).width,
      50,
    );

    await tester.tap(find.byKey(const ValueKey('nav_cart')));
    await _settle(tester);
    expect(find.text('My Cart'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Dining nav opens the dineout screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('nav_dining')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('dineout_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Under ₹250 category tile opens the budget listing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home_best_offers')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_under250')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_under250')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);
    expect(find.text('Under ₹250'), findsWidgets);
    expect(
      find.byKey(const ValueKey('restaurant_filter_budget')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Raised cart keeps the bag badge', (tester) async {
    CartStore.resetForTests();
    CartStore.instance.add(_tee);
    addTearDown(CartStore.resetForTests);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('nav_cart_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_badge_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_badge_count')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
