import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';

const _p = Product(
  id: 41001,
  name: 'Float Bar Tee',
  brand: 'OXRO Select',
  price: 999,
  mrp: 1999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom_outlined,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(CartStore.resetForTests);
  tearDown(CartStore.resetForTests);

  testWidgets('PLP shows floating bar when cart non-empty',
      (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(const MaterialApp(
      home: ProductListingScreen(title: 'T', leafs: ['L1']),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('cart_bar_go')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PLP hides floating bar when cart empty',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProductListingScreen(title: 'T', leafs: ['L1']),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDP has no floating bar (sticky bar only)',
      (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    // Floating bar removed from PDP — content never covered.
    expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    // Sticky Buy bar still present (ADD shows stepper
    // since the cart already holds this product).
    expect(find.byKey(const ValueKey('pdp_buy')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search shows floating bar when cart non-empty',
      (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(
        const MaterialApp(home: SearchScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('cart_bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GO opens Bag from PLP', (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(const MaterialApp(
      home: ProductListingScreen(title: 'T', leafs: ['L1']),
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('cart_bar_go')));
    await _settle(tester);
    expect(find.text('My Cart'), findsOneWidget);
    // Bag has its own totals — no floating bar on top.
    expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
