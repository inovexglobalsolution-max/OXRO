import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/categories/presentation/screens/categories_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

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
  testWidgets('Categories shows all 8 spec cards', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);

    expect(find.text('All Categories'), findsOneWidget);
    for (final name in [
      'Electronics',
      'Fashion & Clothing',
      'Home & Kitchen',
      'Beauty & Personal Care',
      'Sports & Fitness',
      'Books, Stationery & Office',
      'Automotive & Accessories',
      'Toys, Kids & Pet Supplies',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('2.1k items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Grid tap opens L2 left-rail screen', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);

    await tester.tap(find.text('Fashion & Clothing'));
    await _settle(tester);
    // L2: left tabs visible, Men tab selected by default.
    expect(find.text('Women'), findsOneWidget);
    expect(find.text('Men'), findsOneWidget);
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('Footwear & More'), findsOneWidget);
    expect(find.text("Men's Clothing"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('L2 tab switch changes groups (Fashion Men)',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('Fashion & Clothing'));
    await _settle(tester);

    await tester.tap(find.text('Men'));
    await _settle(tester);
    expect(find.text("Men's Clothing"), findsOneWidget);
    // Jewellery exists only on the Women tab — proves the switch.
    expect(find.text('Jewellery'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('L2 group opens PLP with chips + grid',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('Fashion & Clothing'));
    await _settle(tester);
    await tester.tap(find.text('Men'));
    await _settle(tester);

    await tester.tap(find.text("Men's Clothing").first);
    await _settle(tester);
    // PLP: title + leaf buttons + first page.
    expect(find.text("Men · Men's Clothing"), findsOneWidget);
    for (final chip in ['All', 'Shirts', 'T-Shirts', 'Jeans']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('45 styles'), findsOneWidget);

    // Leaf button filters pool.
    await tester.tap(find.text('Jeans'));
    await _pumpFrames(tester);
    expect(find.text('60 styles'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PLP back to L2, L2 back to grid', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('Electronics'));
    await _settle(tester);
    expect(find.text('Mobiles'), findsOneWidget);

    await tester.tap(find.text('Mobiles & Smartphones'));
    await _settle(tester);
    expect(
        find.text('Mobiles · Mobiles & Smartphones'),
        findsOneWidget);
    expect(find.text('5G Phones'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('Mobiles'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('All Categories'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Home Categories tab opens grid, back returns',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.text('Categories'));
    await _settle(tester);
    expect(find.text('All Categories'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('Deals of the Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Categories 320 + tablet no overflow',
      (tester) async {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
          const MaterialApp(home: CategoriesScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('L2 + L3 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
        const MaterialApp(home: CategoriesScreen()));
    await _settle(tester);
    await tester.tap(find.text('Fashion & Clothing'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Kids'));
    await _settle(tester);
    expect(find.text("Kids' Clothing"), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("Kids' Clothing"));
    await _settle(tester);
    expect(find.text("Kids · Kids' Clothing"), findsOneWidget);
    expect(find.text('Boys T-Shirts'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('User catalogue: Ethnic, Cricket, Tyres, Baby paths',
      (tester) async {
    Future<void> openLeaf(
        String category, String tab, String group, String chip) async {
      await tester.pumpWidget(
          const MaterialApp(home: CategoriesScreen()));
      await _settle(tester);
      await tester.scrollUntilVisible(
          find.text(category), 300);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(category));
      await _settle(tester);
      // Tab may already be selected (index 0) — tap anyway.
      await tester.tap(find.text(tab).first);
      await _settle(tester);
      await tester.tap(find.text(group).first);
      await _settle(tester);
      // PLP opens: filter via leaf button, pool becomes 60.
      // (No scrollUntilVisible — PLP has 2 scrollables and the
      // default finder requires exactly one.)
      await tester.tap(find.text(chip));
      await _pumpFrames(tester);
      expect(find.text('60 styles'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    }

    await openLeaf('Fashion & Clothing', 'Women', 'Ethnic Wear',
        'Sarees');
    await openLeaf(
        'Sports & Fitness', 'Games', 'Cricket Equipment', 'Bats');
    await openLeaf('Automotive & Accessories', 'Parts',
        'Tyres & Batteries', 'Tubeless Tyres');
    await openLeaf('Toys, Kids & Pet Supplies', 'Baby', 'Baby Care',
        'Diapers');
    await openLeaf('Electronics', 'Computers', 'Tablets',
        'Android Tablets');
    await openLeaf('Home & Kitchen', 'Bed & Bath',
        'Bedding & Pillows', 'Bedsheets');
    await openLeaf('Beauty & Personal Care', 'Grooming',
        "Men's Grooming", 'Beard Oil');
    await openLeaf('Books, Stationery & Office', 'Office',
        'Office Accessories', 'Calculators');
  });
}
