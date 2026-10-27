import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';
import 'package:oxro/features/wishlist/presentation/screens/wishlist_screen.dart';

const _p1 = Product(
  id: 301,
  name: 'Wish Jacket',
  brand: 'Nike',
  price: 2999,
  mrp: 4999,
  rating: 4.6,
  reviews: 500,
  icon: Icons.checkroom,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
);
const _p2 = Product(
  id: 302,
  name: 'Wish Sneakers',
  brand: 'Puma',
  price: 3999,
  mrp: 5999,
  rating: 4.4,
  reviews: 300,
  icon: Icons.directions_run,
  colors: [Color(0xFFD8EBFF), Color(0xFFA9CDFB)],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _pumpWish(WidgetTester tester,
    {VoidCallback? onDiscover}) async {
  WishlistStore.resetForTests();
  await tester.pumpWidget(MaterialApp(
      home: WishlistScreen(onDiscover: onDiscover ?? () {})));
  await _settle(tester);
}

void main() {
  testWidgets('Empty wishlist shows discover CTA', (tester) async {
    await _pumpWish(tester);

    expect(find.byKey(const ValueKey('wish_empty')), findsOneWidget);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('wish_discover')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Saved items render grid + remove works',
      (tester) async {
    await _pumpWish(tester);
    WishlistStore.instance.toggle(_p1);
    WishlistStore.instance.toggle(_p2);
    await _settle(tester);

    expect(find.byKey(const ValueKey('wish_grid')), findsOneWidget);
    expect(find.byKey(ValueKey('wish_card_${_p1.id}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('wish_card_${_p2.id}')),
        findsOneWidget);

    await tester.tap(find.byKey(ValueKey('wish_remove_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('wish_card_${_p1.id}')),
        findsNothing);
    expect(find.byKey(ValueKey('wish_card_${_p2.id}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Discover calls back', (tester) async {
    var called = false;
    await _pumpWish(tester, onDiscover: () => called = true);

    await tester
        .tap(find.byKey(const ValueKey('wish_discover')));
    await _settle(tester);
    expect(called, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Wishlist opens from Account menu', (tester) async {
    WishlistStore.resetForTests();
    WishlistStore.instance.toggle(_p1);
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    expect(find.text('My Wishlist'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile_wishlist')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('wish_grid')), findsOneWidget);
    expect(find.byKey(ValueKey('wish_card_${_p1.id}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    WishlistStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Wishlist 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      WishlistStore.resetForTests();
      WishlistStore.instance.toggle(_p1);
      WishlistStore.instance.toggle(_p2);
      await tester.pumpWidget(MaterialApp(
          home: WishlistScreen(onDiscover: () {})));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
    WishlistStore.resetForTests();
  });

  // ---- Store unit tests (pure logic) ----
  test('toggle/dedupe/clear/count', () {
    WishlistStore.resetForTests();
    expect(WishlistStore.instance.count, 0);

    WishlistStore.instance.toggle(_p1);
    expect(WishlistStore.instance.contains(_p1.id), isTrue);
    expect(WishlistStore.instance.count, 1);

    WishlistStore.instance.toggle(_p1);
    expect(WishlistStore.instance.contains(_p1.id), isFalse);

    WishlistStore.instance.toggle(_p1);
    WishlistStore.instance.toggle(_p2);
    expect(
        [for (final p in WishlistStore.instance.items) p.id],
        [_p1.id, _p2.id]);

    WishlistStore.instance.remove(_p1.id);
    expect(WishlistStore.instance.count, 1);

    WishlistStore.instance.clear();
    expect(WishlistStore.instance.count, 0);
  });
}
