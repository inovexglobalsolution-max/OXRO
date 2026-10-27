import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';

Finder plpCards() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey &&
          k.value is String &&
          (k.value as String).startsWith('plp_card_');
    });

int cardCount(WidgetTester tester) =>
    plpCards().evaluate().length;

/// Exact Sliver itemCount (built + unbuilt) — precise pagination proof.
int gridItems(WidgetTester tester) {
  final grid =
      tester.widget<GridView>(find.byType(GridView).first);
  final d = grid.childrenDelegate;
  if (d is SliverChildBuilderDelegate) {
    return d.estimatedChildCount ?? -1;
  }
  return -1;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _pumpPlp(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
      home: ProductListingScreen(
    title: "Men · Men's Clothing",
    leafs: const ['Shirts', 'T-Shirts', 'Jeans'],
    icon: Icons.checkroom_outlined,
  )));
  await _frames(tester);
}

void main() {
  testWidgets('PLP renders chips + first page + count',
      (tester) async {
    await _pumpPlp(tester);

    for (final chip in ['All', 'Shirts', 'T-Shirts', 'Jeans']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('45 dishes'), findsOneWidget);
    expect(gridItems(tester), 10);
    // Built-card count is viewport + cache dependent (bottom nav
    // shrinks the test viewport) — delegate count above is the
    // pagination proof; here just prove cards render.
    expect(cardCount(tester), greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Leaf chip filters pool', (tester) async {
    await _pumpPlp(tester);

    await tester.tap(find.text('Jeans'));
    await _frames(tester);
    expect(find.text('60 dishes'), findsOneWidget);
    expect(gridItems(tester), 10);

    await tester.tap(find.text('All'));
    await _frames(tester);
    expect(find.text('45 dishes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Infinite scroll loads more', (tester) async {
    await _pumpPlp(tester);
    expect(gridItems(tester), 10);

    await tester.drag(
        find.byType(GridView), const Offset(0, -2500));
    await _frames(tester, 8);
    expect(gridItems(tester), 20);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Sort sheet reorders grid', (tester) async {
    await _pumpPlp(tester);

    await tester.tap(find.text('Popularity'));
    await _settle(tester);
    expect(find.text('Sort By'), findsOneWidget);

    await tester.tap(find.text('Price: Low to High'));
    await _frames(tester);
    expect(find.text('Sort By'), findsNothing);
    expect(find.text('Price: Low to High'), findsOneWidget);
    expect(gridItems(tester), 10);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Wishlist heart toggles', (tester) async {
    await _pumpPlp(tester);

    expect(find.byIcon(Icons.favorite), findsNothing);
    await tester.ensureVisible(
        find.byIcon(Icons.favorite_outline).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.favorite_outline).first);
    await _settle(tester);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Back pops to previous screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('BASE_MARKER'))));
    await _settle(tester);

    Navigator.of(tester.element(find.text('BASE_MARKER'))).push(
      MaterialPageRoute(
          builder: (_) => ProductListingScreen(
                title: "Men · Men's Clothing",
                leafs: const ['Shirts'],
                icon: Icons.checkroom_outlined,
              )),
    );
    await _frames(tester);
    expect(find.text("Men · Men's Clothing"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _frames(tester);
    expect(find.text('BASE_MARKER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Filter sheet applies brand + clear resets',
      (tester) async {
    await _pumpPlp(tester);

    await tester.tap(find.text('Filter'));
    await _settle(tester);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('BRAND'), findsOneWidget);

    // Pick the first brand chip → Apply → badge appears.
    final brandChips = find.byWidgetPredicate((w) =>
        w.key is ValueKey &&
        (w.key as ValueKey).value is String &&
        ((w.key as ValueKey).value as String)
            .startsWith('filter_brand_'));
    expect(brandChips, findsWidgets);
    await tester.tap(brandChips.first);
    await _settle(tester);

    final apply = find.byKey(const ValueKey('filter_apply'));
    expect(apply, findsOneWidget);
    await tester.ensureVisible(apply);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(apply);
    await _frames(tester);
    expect(find.textContaining('Filter ('), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Reopen → Clear → Apply restores full pool.
    await tester.tap(find.textContaining('Filter ('));
    await _settle(tester);
    await tester.tap(find.text('Clear'));
    await _settle(tester);
    await tester.tap(find.textContaining('Apply ('));
    await _frames(tester);
    expect(find.text('45 dishes'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PLP 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpPlp(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  // ---- Repo unit tests (pure logic) ----
  test('Repo pages 60 products in 10s then ends', () {
    for (var p = 0; p < 6; p++) {
      expect(ProductRepo.page('ns', 'Shirts', p).length, 10);
    }
    expect(ProductRepo.page('ns', 'Shirts', 6), isEmpty);
  });

  test('Repo deterministic per leaf', () {
    final a = ProductRepo.allFor('ns', 'Shirts');
    final b = ProductRepo.allFor('ns', 'Shirts');
    expect(a.length, 60);
    expect(
        [for (final p in a) p.id], [for (final p in b) p.id]);
    expect(a.first.name, contains('Shirts'));
  });

  test('Repo All pool mixes leafs capped at 60', () {
    final all = ProductRepo.allMixed(
        'ns', ['Shirts', 'T-Shirts', 'Jeans'], Icons.checkroom);
    expect(all.length, 45);
  });

  test('sortProducts orders correctly', () {
    final low = Product(
        id: 1,
        name: 'l',
        brand: 'b',
        price: 100,
        mrp: 1000,
        rating: 3.5,
        reviews: 5,
        icon: Icons.checkroom,
        colors: const [Colors.white, Colors.black]);
    final mid = Product(
        id: 2,
        name: 'm',
        brand: 'b',
        price: 500,
        mrp: 1000,
        rating: 4.9,
        reviews: 500,
        icon: Icons.checkroom,
        colors: const [Colors.white, Colors.black]);
    final high = Product(
        id: 3,
        name: 'h',
        brand: 'b',
        price: 900,
        mrp: 1000,
        rating: 4.0,
        reviews: 50,
        icon: Icons.checkroom,
        colors: const [Colors.white, Colors.black]);
    final src = [mid, high, low];
    expect(
        [for (final p in sortProducts(src, PlpSort.priceAsc)) p.id],
        [1, 2, 3]);
    expect(
        [for (final p in sortProducts(src, PlpSort.priceDesc)) p.id],
        [3, 2, 1]);
    expect(
        sortProducts(src, PlpSort.rating).first.id, 2);
    expect(
        sortProducts(src, PlpSort.discount).first.id, 1);
    expect(
        sortProducts(src, PlpSort.popularity).first.id, 2);
  });

  test('filterProducts brand/price/rating/off', () {
    final pool = ProductRepo.allFor('ns', 'Masala Dosa');
    expect(
        filterProducts(pool, const PlpFilters()).length,
        pool.length);

    final kitchen = filterProducts(
        pool, const PlpFilters(brands: {'Paradise Biryani'}));
    expect(
        kitchen.every((p) => p.brand == 'Paradise Biryani'),
        isTrue);

    final cheap = filterProducts(
        pool, const PlpFilters(price: PlpPrice.under200));
    expect(cheap.every((p) => p.price < 200), isTrue);

    final top = filterProducts(
        pool, const PlpFilters(minRating: 4));
    expect(top.every((p) => p.rating >= 4), isTrue);

    final off = filterProducts(
        pool, const PlpFilters(minOff: 50));
    expect(off.every((p) => p.off >= 50), isTrue);

    const combo = PlpFilters(
        brands: {'Paradise Biryani'},
        price: PlpPrice.b200to399,
        minRating: 3,
        minOff: 10);
    final hits = filterProducts(pool, combo);
    expect(
        hits.every((p) =>
            p.brand == 'Paradise Biryani' &&
            p.price >= 200 &&
            p.price < 400 &&
            p.rating >= 3 &&
            p.off >= 10),
        isTrue);
    expect(combo.isActive, isTrue);
    expect(combo.count, 4);
    expect(const PlpFilters().isActive, isFalse);
  });

  test('inr formats Indian grouping', () {
    expect(Product.inr(999), '₹999');
    expect(Product.inr(7838), '₹7,838');
    expect(Product.inr(129999), '₹1,29,999');
  });
}
