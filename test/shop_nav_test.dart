import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/search/presentation/screens/search_screen.dart';
import 'package:oxro/features/categories/presentation/screens/sub_category_screen.dart';

const _p = Product(
  id: 42001,
  name: 'Nav Test Tee',
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

  testWidgets('PLP shows bottom nav until Bag', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProductListingScreen(title: 'T', leafs: ['L1']),
    ));
    await _settle(tester);

    // Shared nav visible with all 5 labels.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Bag'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PLP nav Bag opens Bag (nav hidden there)',
      (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(const MaterialApp(
      home: ProductListingScreen(title: 'T', leafs: ['L1']),
    ));
    await _settle(tester);

    await tester.tap(find.text('Bag'));
    await _settle(tester);
    expect(find.text('Shopping Bag'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PLP nav Home resets to Home tab', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProductListingScreen(title: 'T', leafs: ['L1']),
    ));
    await _settle(tester);

    await tester.tap(find.text('Home'));
    await _settle(tester);
    expect(find.text('Shop by Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDP shows nav + sticky bar, no floating bar',
      (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    expect(find.byKey(const ValueKey('cart_bar')), findsNothing);
    expect(find.byKey(const ValueKey('pdp_buy')), findsOneWidget);
    expect(find.text('Bag'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search shows bottom nav', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SearchScreen()));
    await _settle(tester);

    // Idle body also prints category words — scope to the nav bar.
    final nav = find.byType(BottomNavigationBar);
    expect(nav, findsOneWidget);
    expect(
        find.descendant(of: nav, matching: find.text('Home')),
        findsOneWidget);
    expect(
        find.descendant(of: nav, matching: find.text('Bag')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('L2 shows Show-All card opening full PLP',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SubCategoryScreen(category: homeCategories[1]),
    ));
    await _settle(tester);

    expect(find.byKey(const ValueKey('show_all_products')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('show_all_products')));
    await _settle(tester);
    // Full-collection PLP title carries the All suffix.
    expect(find.textContaining('— All'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shop pages 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    CartStore.instance.add(_p);
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);
    expect(tester.takeException(), isNull,
        reason: 'pdp nav + sticky at 320');
  });
}
