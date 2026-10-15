import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

const _p1 = Product(
  id: 2001,
  name: 'Narrow Jacket',
  brand: 'Nike',
  price: 6099,
  mrp: 7999,
  rating: 4.6,
  reviews: 500,
  icon: Icons.checkroom,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
);
const _p2 = Product(
  id: 2002,
  name: 'Narrow Shoes',
  brand: 'Puma',
  price: 6099,
  mrp: 7999,
  rating: 4.4,
  reviews: 300,
  icon: Icons.directions_run,
  colors: [Color(0xFFD8EBFF), Color(0xFFA9CDFB)],
);
const _p3 = Product(
  id: 2003,
  name: 'Narrow Tee',
  brand: 'OXRO',
  price: 6099,
  mrp: 7999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('Cart bar shows full text at 320 width', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    CartStore.resetForTests();
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    CartStore.instance.add(_p3);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    // Full amount visible (FittedBox shrinks, never ellipsis-cuts).
    expect(
        find.text(
            Product.inr(CartStore.instance.totalPrice)),
        findsOneWidget);
    expect(find.byKey(const ValueKey('cart_bar_go')), findsOneWidget);
    // Total + savings both render (option B).
    expect(find.byKey(ValueKey('cart_bar_total_${CartStore.instance.totalPrice}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('bar_sub_${CartStore.instance.savings}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    // Bar floats on Categories + Orders + Account too, hides on Bag.
    await tester.tap(find.text('Categories'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);

    await tester.tap(find.text('Account'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);

    // Bottom-nav Bag icons: tap the nav item (first Bag match).
    await tester.tap(find.text('Bag').first);
    await _settle(tester);
    expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    expect(tester.takeException(), isNull);

    CartStore.resetForTests();
    await tester.pumpWidget(Container());
  });
}
