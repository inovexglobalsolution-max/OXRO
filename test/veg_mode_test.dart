import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/widgets/dish_row.dart';
import 'package:oxro/app/widgets/restaurant_card.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';

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
    FoodPreferenceStore.resetForTests();
    PremiumStore.resetForTests();
  });

  tearDown(() {
    FoodPreferenceStore.resetForTests();
    PremiumStore.resetForTests();
  });

  test('Food preference store applies both choices and disables', () async {
    final store = FoodPreferenceStore.instance;
    expect(store.enabled, isFalse);
    expect(store.preference, FoodPreference.veg);
    expect(store.activeFilter, isNull);

    await store.apply(FoodPreference.veg);
    expect(store.enabled, isTrue);
    expect(store.vegOnly, isTrue);
    expect(store.nonVegOnly, isFalse);

    await store.apply(FoodPreference.nonVeg);
    expect(store.preference, FoodPreference.nonVeg);
    expect(store.nonVegOnly, isTrue);
    expect(store.vegOnly, isFalse);

    await store.disable();
    expect(store.enabled, isFalse);
    expect(store.activeFilter, isNull);
  });

  testWidgets('Choosing Non-Veg animates then disables on tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('home_veg_mode')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('veg_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('food_pref_nonveg')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('veg_apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.byKey(const ValueKey('veg_transition')), findsOneWidget);
    expect(FoodPreferenceStore.instance.nonVegOnly, isTrue);

    final ring = find.byKey(const ValueKey('veg_transition_ring_0'));
    expect(ring, findsOneWidget);
    final before = tester
        .widget<Transform>(
          find.descendant(of: ring, matching: find.byType(Transform)),
        )
        .transform
        .storage[0];
    await tester.pump(const Duration(milliseconds: 260));
    final after = tester
        .widget<Transform>(
          find.descendant(of: ring, matching: find.byType(Transform)),
        )
        .transform
        .storage[0];
    expect(after, greaterThan(before));

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('veg_transition')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home_veg_mode')));
    await tester.pump();
    expect(FoodPreferenceStore.instance.enabled, isFalse);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('More settings sheet persists Non-Veg choice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('home_veg_mode')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('veg_more_settings')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('veg_settings_enabled')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('food_settings_nonveg')));
    await _settle(tester);
    expect(FoodPreferenceStore.instance.nonVegOnly, isTrue);

    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('veg_settings_enabled')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Veg preference filters the home restaurant feed', (
    tester,
  ) async {
    await FoodPreferenceStore.instance.apply(FoodPreference.veg);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('food_restaurants_header')),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -400),
    );
    await _settle(tester);

    final expected = RestaurantRepo.all.where((r) => r.hasVegDish).length;
    expect(find.text('$expected places match your filters'), findsOneWidget);
    final cards = tester
        .widgetList<RestaurantCard>(find.byType(RestaurantCard))
        .toList();
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.restaurant.hasVegDish), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Non-Veg preference filters the home restaurant feed', (
    tester,
  ) async {
    await FoodPreferenceStore.instance.apply(FoodPreference.nonVeg);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('food_restaurants_header')),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -400),
    );
    await _settle(tester);

    final expected = RestaurantRepo.all.where((r) => r.hasNonVegDish).length;
    expect(find.text('$expected places match your filters'), findsOneWidget);
    final cards = tester
        .widgetList<RestaurantCard>(find.byType(RestaurantCard))
        .toList();
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.restaurant.hasNonVegDish), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Food preference change filters menus while open', (
    tester,
  ) async {
    final r = RestaurantRepo.all.firstWhere(
      (r) =>
          !r.pureVeg &&
          r.dishes.any((d) => d.veg) &&
          r.dishes.any((d) => !d.veg),
    );
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _settle(tester);

    final before = tester.widgetList<DishRow>(find.byType(DishRow));
    expect(before.any((row) => !row.dish.veg), isTrue);

    await FoodPreferenceStore.instance.apply(FoodPreference.veg);
    await _settle(tester);
    final vegRows = tester.widgetList<DishRow>(find.byType(DishRow));
    expect(vegRows, isNotEmpty);
    expect(vegRows.every((row) => row.dish.veg), isTrue);

    await FoodPreferenceStore.instance.apply(FoodPreference.nonVeg);
    await _settle(tester);
    final nonVegRows = tester.widgetList<DishRow>(find.byType(DishRow));
    expect(nonVegRows, isNotEmpty);
    expect(nonVegRows.every((row) => !row.dish.veg), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Empty menu explains the active food preference', (tester) async {
    await FoodPreferenceStore.instance.apply(FoodPreference.nonVeg);
    final pureVeg = RestaurantRepo.pureVeg.first;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: pureVeg.id)),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_empty_menu')), findsOneWidget);
    expect(find.text('No non-veg dishes in this menu'), findsOneWidget);
    expect(find.text('This menu is being refreshed'), findsNothing);
    expect(
      find.byKey(const ValueKey('restaurant_empty_preference')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Offers tile is always visible and opens offers', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home_best_offers')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_best_offers')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);
    expect(find.text('Best offers'), findsWidgets);
    expect(
      find.byKey(const ValueKey('restaurant_filter_offers')),
      findsOneWidget,
    );
    await tester.pageBack();
    await _settle(tester);

    // The FREE DELIVERY slide CTA opens the PREMIUM membership screen.
    await tester.drag(
      find.byKey(const ValueKey('food_banner_carousel')),
      const Offset(-390, 0),
    );
    await _settle(tester);

    final cta = find.byKey(const ValueKey('banner_cta_1'));
    expect(cta, findsOneWidget);
    await tester.ensureVisible(cta);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(cta);
    await _settle(tester);

    expect(find.byKey(const ValueKey('premium_screen')), findsOneWidget);
    expect(find.text('OXRO PREMIUM'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
