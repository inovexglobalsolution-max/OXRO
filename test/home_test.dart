import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/home/presentation/screens/home_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  testWidgets('Home shows reference sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(welcomeName: 'Priya')));
    await _settle(tester);

    expect(find.textContaining('Chennai'), findsOneWidget);
    // 2-row header: wallet pill (live balance) + profile + voice.
    expect(find.byKey(const ValueKey('wallet_pill')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('wallet_balance')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile_btn')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('voice_btn')),
        findsOneWidget);
    // Banners are image-only art now: assert carousel presence.
    expect(find.byKey(const ValueKey('banner_cta_0')),
        findsOneWidget);
    expect(find.text('Shop by Category'), findsOneWidget);
    expect(find.text('Best Sellers'), findsOneWidget);
    expect(find.textContaining('Welcome to OXRO, Priya!'),
        findsOneWidget);
    expect(find.text('Nike Air Max 270'), findsOneWidget);
    // Feed slivers build lazily — scroll until visible, then assert.
    await tester.dragUntilVisible(
      find.text("Today's Offers"),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -500),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text("Today's Offers"), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('offers_live')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('LIVE badge blinks green dot', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('offers_live')),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    final dot =
        find.byKey(const ValueKey('offers_live_dot'));
    expect(dot, findsOneWidget);
    final o1 = tester.widget<AnimatedOpacity>(find.ancestor(
        of: dot, matching: find.byType(AnimatedOpacity)).first);
    await tester.pump(const Duration(milliseconds: 1200));
    final o2 = tester.widget<AnimatedOpacity>(find.ancestor(
        of: dot, matching: find.byType(AnimatedOpacity)).first);
    expect(o1.opacity == 1.0 || o2.opacity == 1.0, isTrue);
    expect(o1.opacity != o2.opacity, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Category circle opens L2 sub-categories',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    // Bring the strip clear of the bottom nav before tapping.
    await tester.dragUntilVisible(
      find.text('Fashion'),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(find.text('Fashion'));
    await _settle(tester);
    // L2 header carries the full spec name.
    expect(find.text('Fashion & Clothing'), findsOneWidget);
    expect(find.text('Women'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Scroll loads Today\'s Offers feed', (tester) async {
    final homeScroll = find.byKey(const ValueKey('home_scroll'));
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    // Scroll to the feed section (grid made content taller).
    await tester.dragUntilVisible(
      find.text("Today's Offers"),
      homeScroll,
      const Offset(0, -500),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Feed product cards render while scrolling.
    expect(find.textContaining("Today's Offers"),
        findsWidgets);
    expect(find.textContaining('Classic'), findsWidgets);
    // Scroll more → infinite load, no crash.
    await tester.drag(homeScroll, const Offset(0, -2500));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining("Today's Offers"),
        findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('See All opens offers listing', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    // Feed header builds lazily — scroll until visible, then tap its See All.
    await tester.dragUntilVisible(
      find.text("Today's Offers"),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -500),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Feed's See All is the last one (deals' is first).
    final seeAll = find.text('See All >').last;
    await tester.ensureVisible(seeAll);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(seeAll);
    await _settle(tester);
    expect(find.text("Today's Offers"), findsWidgets);
    expect(find.text('Electronics'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Wishlist heart toggles with pop', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byIcon(Icons.favorite), findsNothing);
    final heart = find.byIcon(Icons.favorite_outline).first;
    await tester.ensureVisible(heart);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(heart);
    await _settle(tester);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bottom tabs switch to orders + account', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.text('Categories'));
    await _settle(tester);
    expect(find.text('All Categories'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await _settle(tester);
    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Past Orders'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await _settle(tester);
    expect(find.text('My Wishlist'), findsOneWidget);
    expect(find.text('Guest User'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('All-in-One banner first opens Categories tab',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    // First art page present (image-only, keyed by index).
    expect(find.byKey(const ValueKey('banner_cta_0')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('banner_cta_0')));
    await _settle(tester);
    expect(find.text('All Categories'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Category grid is static Blinkit-style (no auto-scroll)',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    final grid =
        find.byKey(const ValueKey('home_cat_strip'));
    expect(grid, findsOneWidget);
    expect(tester.widget<GridView>(grid).gridDelegate
        is SliverGridDelegateWithFixedCrossAxisCount, isTrue);
    // All 8 fashion categories visible without scrolling.
    expect(find.text('Fashion'), findsOneWidget);
    expect(find.text('Electro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Mid-scroll inline ads appear in feed', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    // Static banner before the feed.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('feed_ad_top')),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('feed_ad_top')),
        findsOneWidget);
    expect(find.text('Festive Edit — Min 50% OFF'),
        findsOneWidget);

    // Tapping an ad opens its category, no crash.
    await tester.tap(find.byKey(const ValueKey('feed_ad_top')));
    await _settle(tester);
    expect(find.text('Fashion & Clothing'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await _settle(tester);

    // Repeating ad after the first 10 feed items.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('feed_ad_0')),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('feed_ad_0')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home 320 + 390 no overflow', (tester) async {    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(
          home: HomeScreen(welcomeName: 'Priya')));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('Header wallet opens WalletScreen', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('wallet_pill')));
    await _settle(tester);
    expect(find.text('OXRO Balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Header profile jumps to Account tab', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    expect(find.text('Guest User'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
