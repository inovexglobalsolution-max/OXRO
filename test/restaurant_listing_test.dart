import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_listing_screen.dart';
import 'package:oxro/features/restaurants/presentation/widgets/restaurant_menu_section.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Widget _listing() => const MaterialApp(
  home: RestaurantListingScreen(title: 'Biryani', cuisine: 'Biryani'),
);

void main() {
  setUp(CartStore.resetForTests);

  testWidgets('Listing shows image tabs and the dish carousel', (tester) async {
    final first = RestaurantRepo.forCuisine('Biryani').first;
    final topDish = ([...first.dishes]
          ..sort((a, b) => b.reviews.compareTo(a.reviews)))
        .first;

    await tester.pumpWidget(_listing());
    await _settle(tester);

    expect(find.byKey(const ValueKey('listing_tabs')), findsOneWidget);
    expect(find.byKey(const ValueKey('listing_tab_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('listing_tab_1')), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(
      find.byKey(ValueKey('restaurant_card_${first.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('restaurant_view_menu_${first.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('restaurant_dish_${first.id}_${topDish.id}')),
      findsOneWidget,
    );
    expect(find.text('View full menu'), findsWidgets);
    expect(find.text('View cart'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('View full menu opens the restaurant', (tester) async {
    final first = RestaurantRepo.forCuisine('Biryani').first;
    await tester.pumpWidget(_listing());
    await _settle(tester);

    final cta = find.byKey(ValueKey('restaurant_view_menu_${first.id}'));
    await tester.ensureVisible(cta);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(cta);
    await _settle(tester);

    expect(find.byKey(const ValueKey('restaurant_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('View cart pill opens the bag', (tester) async {
    final first = RestaurantRepo.forCuisine('Biryani').first;
    final topDish = ([...first.dishes]
          ..sort((a, b) => b.reviews.compareTo(a.reviews)))
        .first;
    CartStore.instance.add(topDish);

    await tester.pumpWidget(_listing());
    await _settle(tester);

    final pill = find.byKey(
      ValueKey('restaurant_dish_cart_${first.id}_${topDish.id}'),
    );
    await tester.ensureVisible(pill);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(pill);
    await _settle(tester);

    expect(find.byKey(const ValueKey('bag_restaurant')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Tapping a dish card opens the customize sheet', (tester) async {
    final first = RestaurantRepo.forCuisine('Biryani').first;
    final topDish = ([...first.dishes]
          ..sort((a, b) => b.reviews.compareTo(a.reviews)))
        .first;

    await tester.pumpWidget(_listing());
    await _settle(tester);

    final card = find.byKey(
      ValueKey('restaurant_dish_${first.id}_${topDish.id}'),
    );
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customize_add')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await tester.pumpAndSettle();

    expect(CartStore.instance.contains(topDish.id), isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Category tab filters the restaurants', (tester) async {
    await tester.pumpWidget(_listing());
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('listing_tab_1')));
    await _settle(tester);

    final sections = tester
        .widgetList<RestaurantMenuSection>(find.byType(RestaurantMenuSection))
        .toList();
    expect(sections, isNotEmpty);
    expect(
      sections.every(
        (s) => s.restaurant.menu.any(
          (m) => m.dishes.any(
            (d) => d.name.toLowerCase().contains('chicken biryani'),
          ),
        ),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Listing lays out at 320 / 390 / 768 widths', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [320.0, 390.0, 768.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(_listing());
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }
    await _dispose(tester);
  });
}
