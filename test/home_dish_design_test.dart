import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/home/data/food_preference_store.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/home/presentation/widgets/dish_spotlight.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 220));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _showDishSections(WidgetTester tester) async {
  final scroll = find.byKey(const ValueKey('home_scroll'));
  await tester.dragUntilVisible(
    find.byKey(const ValueKey('home_fast_dishes')),
    scroll,
    const Offset(0, -220),
  );
  await _settle(tester);
}

String _fastDishKey(RestaurantDish item) {
  return 'home_fast_dish_${item.restaurant.id}_${item.dish.id}';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FoodPreferenceStore.resetForTests();
  });

  tearDown(FoodPreferenceStore.resetForTests);

  testWidgets('Home shows only the fast dish rail', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showDishSections(tester);

    expect(find.byKey(const ValueKey('home_dish_spotlight')), findsNothing);
    expect(find.byKey(const ValueKey('home_fast_dishes')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_fast_dishes_rail')), findsOneWidget);

    final rail = tester.widget<FastDishRail>(find.byType(FastDishRail));
    expect(rail.items.length, greaterThan(6));
    expect(
      rail.items.every((item) => item.restaurant.etaMinutes <= 30),
      isTrue,
    );
    expect(rail.items.any((item) => item.restaurant.id == 'r_bbq'), isFalse);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Fast dish rail sits after the first two restaurant cards', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('home_fast_dishes')), findsNothing);

    final scroll = tester.widget<CustomScrollView>(
      find.byKey(const ValueKey('home_scroll')),
    );
    final keys = scroll.slivers.map((sliver) => sliver.key).toList();
    final before = keys.indexOf(
      const ValueKey('food_restaurant_feed_before_fast'),
    );
    final rail = keys.indexOf(const ValueKey('home_fast_dishes_sliver'));
    final after = keys.indexOf(
      const ValueKey('food_restaurant_feed_after_fast'),
    );

    expect(before, isNonNegative);
    expect(rail, before + 1);
    expect(after, rail + 1);

    final beforeSliver = scroll.slivers[before] as SliverPadding;
    final delegate =
        (beforeSliver.child as SliverList).delegate
            as SliverChildBuilderDelegate;
    expect(delegate.childCount, 3);

    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Fast dish card opens its restaurant menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showDishSections(tester);

    final rail = tester.widget<FastDishRail>(find.byType(FastDishRail));
    final first = rail.items.first;
    final card = find.byKey(ValueKey(_fastDishKey(first)));
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await _settle(tester);
    await tester.tap(card);
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Scroll reveals dishes after the first six', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showDishSections(tester);

    final rail = tester.widget<FastDishRail>(find.byType(FastDishRail));
    expect(rail.items.length, greaterThan(6));
    final seventh = rail.items[6];
    final seventhCard = find.byKey(ValueKey(_fastDishKey(seventh)));
    expect(seventhCard, findsNothing);

    await tester.dragUntilVisible(
      seventhCard,
      find.byKey(const ValueKey('home_fast_dishes_rail')),
      const Offset(-220, 0),
    );
    await _settle(tester);

    expect(seventhCard, findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Dish sections respect veg preference', (tester) async {
    await FoodPreferenceStore.instance.apply(FoodPreference.veg);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showDishSections(tester);

    final rail = tester.widget<FastDishRail>(find.byType(FastDishRail));
    expect(rail.items, isNotEmpty);
    expect(rail.items.every((item) => item.dish.veg), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Fast dish rail fits a 320px phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await _showDishSections(tester);

    expect(find.byKey(const ValueKey('home_dish_spotlight')), findsNothing);
    expect(find.byKey(const ValueKey('home_fast_dishes')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
