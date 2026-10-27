import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/categories/presentation/screens/categories_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_listing_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpFrames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  testWidgets('Categories shows all 30 food cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);

    expect(find.text('All Categories'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    for (final name in [
      'Biryani',
      'North Indian',
      'South Indian',
      'Chinese',
      'Pizza',
      'Burgers',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('320 dishes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Grid tap opens L2 sub-category list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);

    await tester.tap(find.text('Biryani'));
    await _settle(tester);
    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Mutton Biryani'), findsOneWidget);
    expect(find.text('Explore dishes'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('L2 sub opens PLP with chips + grid', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('Biryani'));
    await _settle(tester);

    await tester.tap(find.text('Chicken Biryani'));
    await _settle(tester);
    // PLP: title + chips + first page.
    expect(find.text('Biryani · Chicken Biryani'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('15 dishes'), findsOneWidget);

    // Chip filters pool to the full 60 dishes.
    await tester.tap(find.text('Chicken Biryani').last);
    await _pumpFrames(tester);
    expect(find.text('60 dishes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PLP back to L2, L2 back to grid', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('Pizza'));
    await _settle(tester);
    expect(find.text('Margherita'), findsOneWidget);

    await tester.tap(find.text('Margherita'));
    await _settle(tester);
    expect(find.text('Pizza · Margherita'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('Margherita'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('All Categories'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home cuisine rail opens listing, back returns', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('food_cuisine_3')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('restaurant_list')), findsOneWidget);

    await tester.pageBack();
    await _settle(tester);
    expect(find.byKey(const ValueKey('home_quick_cats')), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('food_cuisine_underline_3')))
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

  testWidgets('Categories 320 + tablet no overflow', (tester) async {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('L2 + PLP 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('South Indian'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Masala Dosa'));
    await _settle(tester);
    expect(find.text('South Indian · Masala Dosa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Empty cuisine listing offers dish discovery', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RestaurantListingScreen(title: 'Thai', cuisine: 'Thai'),
      ),
    );
    await _settle(tester);

    expect(find.text('No restaurants match these filters.'), findsOneWidget);
    final browse = find.byKey(
      const ValueKey('restaurant_listing_browse_dishes'),
    );
    expect(browse, findsOneWidget);

    await tester.tap(browse);
    await _settle(tester);
    expect(find.text('Thai Green Curry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Food catalogue: sub-category paths across cuisines', (
    tester,
  ) async {
    Future<void> openSub(String category, String sub, String chip) async {
      await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
      await _settle(tester);
      await tester.scrollUntilVisible(find.text(category), 300);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(category));
      await _settle(tester);
      await tester.tap(find.text(sub).first);
      await _settle(tester);
      // PLP opens: filter via chip, pool becomes 60.
      await tester.tap(find.text(chip).last);
      await _pumpFrames(tester);
      expect(find.text('60 dishes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    }

    await openSub('Biryani', 'Mutton Biryani', 'Mutton Biryani');
    await openSub('Chinese', 'Veg Noodles', 'Veg Noodles');
    await openSub('Momos', 'Chicken Momos', 'Chicken Momos');
    await openSub('Desserts', 'Gulab Jamun', 'Gulab Jamun');
    await openSub('Kerala', 'Appam', 'Appam');
    await openSub('Street Food', 'Pav Bhaji', 'Pav Bhaji');
    await openSub('Healthy & Salads', 'Caesar Salad', 'Caesar Salad');
    await openSub('Tea & Coffee', 'Filter Coffee', 'Filter Coffee');
  });
}
