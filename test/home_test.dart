import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/search/data/search_repo.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  testWidgets('Home shows food-first sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(welcomeName: 'Priya')),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('home_scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('food_location')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet_pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('food_search')), findsOneWidget);
    expect(find.byKey(const ValueKey('food_mic')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_veg_mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_cuisine_strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_quick_cats')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_promo_hero')), findsOneWidget);
    expect(find.byKey(const ValueKey('banner_cta_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_dineout_banner')), findsNothing);
    expect(find.byKey(const ValueKey('home_service_strip')), findsNothing);
    final scroll = find.byKey(const ValueKey('home_scroll'));
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('home_deals_header')),
      scroll,
      const Offset(0, -300),
    );
    await _settle(tester);
    expect(find.text('RECOMMENDED WITH DEALS'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_deal_rail')), findsOneWidget);
    final firstDeal = RestaurantRepo.offers.first;
    expect(
      find.byKey(ValueKey('home_deal_restaurant_${firstDeal.id}')),
      findsOneWidget,
    );
    expect(find.text('Near & Fast'), findsWidgets);
    expect(find.text('30-35 mins'), findsWidgets);
    expect(find.byKey(const ValueKey('home_deals_see_all')), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('food_restaurants_header')),
      scroll,
      const Offset(0, -400),
    );
    await _settle(tester);
    expect(find.text('Restaurants near you'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Best sellers'),
      scroll,
      const Offset(0, -400),
    );
    await _settle(tester);
    expect(find.text('Best sellers'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Cuisine rail opens restaurant listing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('food_cuisine_1')));
    await _settle(tester);

    expect(find.text('Biryani'), findsWidgets);
    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('restaurant_count')), findsOneWidget);

    await tester.pageBack();
    await _settle(tester);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('food_cuisine_underline_1')))
          .width,
      greaterThan(20),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('food_cuisine_underline_0')))
          .width,
      0,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('See all opens the restaurant listing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    final header = find.byKey(const ValueKey('food_restaurants_header'));
    await tester.dragUntilVisible(
      header,
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -400),
    );
    await _settle(tester);
    await tester.tap(
      find.descendant(of: header, matching: find.text('See all')),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);
    expect(find.text('Restaurants near you'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Restaurant card opens the menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    final id = RestaurantRepo.all.first.id;
    final card = find.byKey(ValueKey('restaurant_card_$id'));
    await tester.dragUntilVisible(
      card,
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -400),
    );
    await _settle(tester);
    await tester.tap(card);
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('First banner opens a restaurant listing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    final cta = find.byKey(const ValueKey('banner_cta_0'));
    await tester.ensureVisible(cta);
    await _settle(tester);
    await tester.tap(cta);
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Search field opens search', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('food_search')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('search_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home search hint rotates dish names', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    final hint = find.byKey(const ValueKey('food_search_hint'));
    expect(hint, findsOneWidget);
    String current() => tester
        .widgetList<Text>(
          find.descendant(of: hint, matching: find.byType(Text)),
        )
        .last
        .textSpan!
        .toPlainText();
    final before = current();
    expect(before, isNotEmpty);
    expect(
      SearchRepo.dishNames.any((n) => before.contains(n)),
      isTrue,
      reason: 'hint should show a dish name',
    );

    await tester.pump(const Duration(milliseconds: 3300));
    expect(current(), isNot(before));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home search hint keeps full name at 320', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    final hint = find.byKey(const ValueKey('food_search_hint'));
    expect(hint, findsOneWidget);
    expect(
      find.descendant(of: hint, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    final label = tester
        .widget<Text>(
          find.descendant(of: hint, matching: find.byType(Text)).last,
        )
        .textSpan!
        .toPlainText();
    expect(label, isNotEmpty);
    expect(
      SearchRepo.dishNames.any((n) => label.contains(n)),
      isTrue,
      reason: 'full dish name should be rendered',
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Reference nav opens budget category, dining, account + orders', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Dining'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_cart')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_under250')), findsNothing);
    expect(find.byKey(const ValueKey('home_under250')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_account')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home_under250')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);
    expect(find.text('Under ₹250'), findsWidgets);
    expect(
      find.byKey(const ValueKey('restaurant_filter_budget')),
      findsOneWidget,
    );
    final budgetIds = filterRestaurants(
      RestaurantRepo.all,
      const RestaurantFilters(maxCostForTwo: 250),
    ).map((r) => r.id).toSet();
    expect(budgetIds, isNotEmpty);
    expect(budgetIds.length, lessThan(RestaurantRepo.all.length));
    await tester.pageBack();
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('nav_dining')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('dineout_screen')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    expect(find.text('My Wishlist'), findsOneWidget);
    expect(find.text('Guest User'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_orders')));
    await _settle(tester);
    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Past Orders'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav_delivery')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('home_scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(welcomeName: 'Priya')),
      );
      await _settle(tester);
      final visible = size.width < 340 ? 3 : 4;
      for (var i = 0; i < visible; i++) {
        final item = find.byKey(ValueKey('food_cuisine_$i'));
        expect(item, findsOneWidget, reason: 'cuisine $i at $size');
        expect(
          tester.getRect(item).right,
          lessThanOrEqualTo(size.width - 15),
          reason: 'cuisine $i should fit without dead space at $size',
        );
      }

      final bestOffers = find.byKey(const ValueKey('home_best_offers'));
      final under250 = find.byKey(const ValueKey('home_under250'));
      final firstCuisine = find.byKey(const ValueKey('food_cuisine_0'));
      final lastCuisine = find.byKey(ValueKey('food_cuisine_${visible - 1}'));
      expect(
        tester.getCenter(bestOffers).dx,
        lessThan(tester.getCenter(firstCuisine).dx),
        reason: 'Best Offers stays on the left at $size',
      );
      expect(
        tester.getCenter(under250).dx,
        lessThan(tester.getCenter(firstCuisine).dx),
        reason: 'Under ₹250 sits at left end at $size',
      );
      expect(
        tester.getRect(under250).left,
        lessThan(size.width * 0.2),
        reason: 'Under ₹250 hugs the left edge at $size',
      );
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('Header wallet opens WalletScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('wallet_pill')));
    await _settle(tester);
    expect(find.text('OXRO Balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Header profile jumps to Account tab', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    expect(find.text('Guest User'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
