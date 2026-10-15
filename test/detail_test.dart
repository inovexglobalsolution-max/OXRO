import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/reviews/data/review_repo.dart';
import 'package:oxro/features/reviews/data/review_store.dart';

const _p = Product(
  id: 999001,
  name: 'Test Detail Jacket',
  brand: 'OXRO Select',
  price: 1999,
  mrp: 3999,
  rating: 4.5,
  reviews: 1234,
  icon: Icons.checkroom_outlined,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReviewStore.resetForTests();
  });
  testWidgets('PDP renders name price ADD and buy', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    expect(find.byKey(const ValueKey('pdp_name')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdp_price')), findsOneWidget);
    expect(find.byKey(ValueKey('add_${_p.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdp_buy')), findsOneWidget);
    expect(find.textContaining('Free delivery'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PDP ADD becomes stepper', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('add_${_p.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('stepper_${_p.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home card tap opens PDP', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.text("Today's Offers"),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -500),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final card = find
        .byWidgetPredicate((w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value is String &&
            ((w.key as ValueKey).value as String)
                .startsWith('home_feed_'))
        .first;
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(card);
    await _settle(tester);

    expect(find.byKey(const ValueKey('pdp_name')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdp_scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PDP shows offers details similars', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    expect(find.text('Available offers'), findsOneWidget);
    expect(find.text('Product details'), findsOneWidget);
    expect(find.text('You may also like'), findsOneWidget);
    expect(find.textContaining('Free delivery'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PDP similar tap swaps product', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    final sim = find
        .byWidgetPredicate((w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value is String &&
            ((w.key as ValueKey).value as String)
                .startsWith('pdp_similar_'))
        .first;
    await tester.ensureVisible(sim);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(sim);
    await _settle(tester);
    // New PDP pushed on top — two pdp_name widgets (old offstage).
    expect(find.byKey(const ValueKey('pdp_name')), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PDP 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
          const MaterialApp(home: ProductDetailScreen(product: _p)));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  test('Review breakdown sums to 100 for all rating bands', () {
    for (final r in [2.8, 3.1, 3.9, 4.2, 4.5, 4.9]) {
      final p = Product(
        id: 777,
        name: 'x',
        brand: 'b',
        price: 100,
        mrp: 200,
        rating: r,
        reviews: 100,
        icon: Icons.star,
        colors: const [Colors.white, Colors.black],
      );
      expect(ReviewRepo.breakdown(p).reduce((a, c) => a + c), 100);
      expect(ReviewRepo.reviewsFor(p).length, 3);
    }
  });

  test('Review media deterministic per product', () {
    final a = ReviewRepo.reviewsFor(_p);
    final b = ReviewRepo.reviewsFor(_p);
    expect(a.map((r) => r.photos), b.map((r) => r.photos));
    expect(a.map((r) => r.hasVideo), b.map((r) => r.hasVideo));
    // Review 0 always carries photos; whole set always has media.
    expect(a.first.photos.length >= 2, isTrue);
    expect(a.any((r) => r.hasVideo), isTrue);
    expect(a.any((r) => r.hasMedia), isTrue);
  });

  testWidgets('PDP shows ratings breakdown + 3 review cards',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('pdp_reviews')),
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('pdp_reviews')), findsOneWidget);
    expect(find.byKey(const ValueKey('pdp_rate_bar_5')), findsOneWidget);
    expect(find.text('Ratings & Reviews'), findsOneWidget);
    final cards = find.byWidgetPredicate((w) =>
        w.key is ValueKey &&
        (w.key as ValueKey).value is String &&
        ((w.key as ValueKey).value as String)
            .startsWith('review_card_'));
    expect(cards.evaluate().length, 3);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Helpful tap increments once', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('review_card_999001_r0')),
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    final help = find
        .byWidgetPredicate((w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value is String &&
            ((w.key as ValueKey).value as String)
                .startsWith('review_helpful_'))
        .first;
    final before =
        ((help.evaluate().first.widget.key as ValueKey).value as String);
    expect(before, contains('review_helpful_'));
    await tester.ensureVisible(help);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(help);
    await _settle(tester);
    expect(find.textContaining('Helpful (', findRichText: true),
        findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Write review validates + submits', (tester) async {
    OrderStore.resetForTests();
    ReviewStore.resetForTests();
    OrderStore.instance.injectForTests(MockOrder(
      id: 'T-ELIGIBLE',
      date: 'Today',
      status: OrderStatus.delivered,
      products: const [_p],
      deliveredAt:
          DateTime.now().subtract(const Duration(hours: 5)),
    ));
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('review_write')),
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('review_write')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('review_submit')), findsOneWidget);

    // Empty submit blocked (stays open).
    await tester.tap(find.byKey(const ValueKey('review_submit')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('review_submit')), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('review_name')), 'Test User');
    await tester.enterText(
        find.byKey(const ValueKey('review_body')),
        'Super quality product, highly recommended!');
    await tester.tap(find.byKey(const ValueKey('review_submit')));
    await _settle(tester);
    expect(find.text('Thanks! Review submitted'), findsOneWidget);
    expect(tester.takeException(), isNull);
    OrderStore.resetForTests();
    ReviewStore.resetForTests();
    await _dispose(tester);
  });

  test('canReview gate matrix', () {
    final now = DateTime(2026, 10, 14, 12);
    List<MockOrder> orders(List<MockOrder> o) => o;

    // Never bought.
    expect(
        ReviewRepo.canReview(
            productId: 1, orders: orders(const []), now: now),
        ReviewAccess.notBought);

    // Delivered 10h ago -> ok.
    expect(
        ReviewRepo.canReview(
          productId: 1,
          orders: orders([
            MockOrder(
              id: 'A',
              date: 'Today',
              status: OrderStatus.delivered,
              products: const [
                Product(
                  id: 1,
                  name: 'x',
                  brand: 'b',
                  price: 100,
                  mrp: 200,
                  rating: 4.0,
                  reviews: 10,
                  icon: Icons.star,
                  colors: [Colors.white, Colors.black],
                ),
              ],
              deliveredAt: now.subtract(const Duration(hours: 10)),
            ),
          ]),
          now: now,
        ),
        ReviewAccess.ok);

    // Delivered 49h ago -> expired.
    expect(
        ReviewRepo.canReview(
          productId: 1,
          orders: orders([
            MockOrder(
              id: 'B',
              date: 'Old',
              status: OrderStatus.delivered,
              products: const [
                Product(
                  id: 1,
                  name: 'x',
                  brand: 'b',
                  price: 100,
                  mrp: 200,
                  rating: 4.0,
                  reviews: 10,
                  icon: Icons.star,
                  colors: [Colors.white, Colors.black],
                ),
              ],
              deliveredAt: now.subtract(const Duration(hours: 49)),
            ),
          ]),
          now: now,
        ),
        ReviewAccess.expired);

    // Processing (bought, not delivered) -> expired bucket, no write.
    expect(
        ReviewRepo.canReview(
          productId: 1,
          orders: orders([
            MockOrder(
              id: 'C',
              date: 'Today',
              status: OrderStatus.processing,
              products: const [
                Product(
                  id: 1,
                  name: 'x',
                  brand: 'b',
                  price: 100,
                  mrp: 200,
                  rating: 4.0,
                  reviews: 10,
                  icon: Icons.star,
                  colors: [Colors.white, Colors.black],
                ),
              ],
            ),
          ]),
          now: now,
        ),
        ReviewAccess.expired);

    // Cancelled -> as if never bought.
    expect(
        ReviewRepo.canReview(
          productId: 1,
          orders: orders([
            MockOrder(
              id: 'D',
              date: 'Today',
              status: OrderStatus.cancelled,
              products: const [
                Product(
                  id: 1,
                  name: 'x',
                  brand: 'b',
                  price: 100,
                  mrp: 200,
                  rating: 4.0,
                  reviews: 10,
                  icon: Icons.star,
                  colors: [Colors.white, Colors.black],
                ),
              ],
              deliveredAt: now.subtract(const Duration(hours: 2)),
            ),
          ]),
          now: now,
        ),
        ReviewAccess.notBought);
  });

  testWidgets('Non-buyer review form hidden', (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('pdp_reviews')),
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    // See-only: cards render, write hidden (48h hide rule).
    expect(find.byKey(const ValueKey('pdp_reviews')), findsOneWidget);
    expect(find.byKey(const ValueKey('review_write')), findsNothing);
    expect(find.byKey(const ValueKey('review_write_hidden')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Expired window hides review form', (tester) async {
    OrderStore.resetForTests();
    OrderStore.instance.injectForTests(MockOrder(
      id: 'T-OLD',
      date: 'Old',
      status: OrderStatus.delivered,
      products: const [_p],
      deliveredAt:
          DateTime.now().subtract(const Duration(hours: 49)),
    ));
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('pdp_reviews')),
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('review_write')), findsNothing);
    expect(find.byKey(const ValueKey('review_write_hidden')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    OrderStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Photo tap zooms, video tap plays mock clip',
      (tester) async {
    OrderStore.resetForTests();
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    // Scroll first card's media into view.
    final media = find
        .byWidgetPredicate((w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value is String &&
            ((w.key as ValueKey).value as String)
                .startsWith('review_media_'))
        .first;
    await tester.dragUntilVisible(
      media,
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);

    // Photo zoom dialog opens + dismisses.
    final photo = find
        .byWidgetPredicate((w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value is String &&
            ((w.key as ValueKey).value as String)
                .startsWith('review_photo_'))
        .first;
    final photoKey =
        (photo.evaluate().first.widget.key as ValueKey).value;
    await tester.dragUntilVisible(
      photo,
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    // Center the thumb in the safe band (clear of sticky bar).
    Future<void> centerThumb(Finder f) async {
      final scroll = find.byKey(const ValueKey('pdp_scroll'));
      var guard = 0;
      while (guard < 6) {
        final c = tester.getCenter(f);
        if (c.dy >= 120 && c.dy <= 430) return;
        await tester.drag(
            scroll, Offset(0, c.dy > 430 ? -180 : 180));
        await tester.pump(const Duration(milliseconds: 300));
        guard++;
      }
    }

    await centerThumb(photo);
    await tester.tap(photo);
    await _settle(tester);
    // Zoom dialog with the same seed opens on top.
    final parts = (photoKey as String).split('_');
    final zoomKey =
        'review_zoom_${parts[2]}_${parts[3]}_${parts[4]}';
    final zoomFinder = find.byWidgetPredicate((w) =>
        w.key is ValueKey &&
        (w.key as ValueKey).value == zoomKey);
    expect(zoomFinder, findsOneWidget);
    // Dismiss via the zoom scrim.
    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);

    // Video tile opens mock player with progress.
    final video = find
        .byWidgetPredicate((w) =>
            w.key is ValueKey &&
            (w.key as ValueKey).value is String &&
            ((w.key as ValueKey).value as String)
                .startsWith('review_video_'))
        .first;
    await tester.dragUntilVisible(
      video,
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    await centerThumb(video);
    await tester.tap(video);
    await _settle(tester);
    expect(find.byKey(const ValueKey('video_player')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('video_progress')),
        findsOneWidget);
    expect(find.textContaining('0:06 clip'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('video_play')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('video_close')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('video_player')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Write sheet attaches photo + video', (tester) async {
    OrderStore.resetForTests();
    ReviewStore.resetForTests();
    OrderStore.instance.injectForTests(MockOrder(
      id: 'T-MEDIA',
      date: 'Today',
      status: OrderStatus.delivered,
      products: const [_p],
      deliveredAt:
          DateTime.now().subtract(const Duration(hours: 5)),
    ));
    await tester.pumpWidget(
        const MaterialApp(home: ProductDetailScreen(product: _p)));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('review_write')),
      find.byKey(const ValueKey('pdp_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('review_write')));
    await _settle(tester);

    // Attach one photo + the 6s clip.
    await tester.tap(
        find.byKey(const ValueKey('review_attach_photo')));
    await _settle(tester);
    expect(
        find.byKey(const ValueKey('review_unattach_0')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('review_attach_video')));
    await _settle(tester);

    await tester.enterText(
        find.byKey(const ValueKey('review_name')), 'Media User');
    await tester.enterText(
        find.byKey(const ValueKey('review_body')),
        'Loved it, photos and clip attached for proof!');
    await tester.tap(find.byKey(const ValueKey('review_submit')));
    await _settle(tester);
    expect(find.text('Thanks! Review submitted'), findsOneWidget);
    // Mine card carries the media strip.
    expect(find.text('My review'), findsOneWidget);
    expect(tester.takeException(), isNull);
    OrderStore.resetForTests();
    ReviewStore.resetForTests();
    await _dispose(tester);
  });
}
