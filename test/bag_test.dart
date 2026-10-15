import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';

const _p1 = Product(
  id: 201,
  name: 'Bag Shirt',
  brand: 'OXRO',
  price: 799,
  mrp: 999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);
const _p2 = Product(
  id: 202,
  name: 'Bag Shoes',
  brand: 'Nike',
  price: 1999,
  mrp: 2999,
  rating: 4.5,
  reviews: 200,
  icon: Icons.directions_run,
  colors: [Colors.white, Colors.black],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _pumpBag(WidgetTester tester,
    {VoidCallback? onShopNow}) async {
  CartStore.resetForTests();
  await tester.pumpWidget(MaterialApp(
      home: BagScreen(onShopNow: onShopNow ?? () {})));
  await _settle(tester);
}

void main() {
  testWidgets('Empty bag shows CTA', (tester) async {
    await _pumpBag(tester);

    expect(find.byKey(const ValueKey('bag_empty')), findsOneWidget);
    expect(find.text('Your bag is empty'), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_shop_now')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Lines render with bill math', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    CartStore.instance.increment(_p2.id);
    await _settle(tester);

    expect(find.byKey(const ValueKey('bag_lines')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_line_${_p1.id}')),
        findsOneWidget);
    expect(find.byKey(ValueKey('bag_line_${_p2.id}')),
        findsOneWidget);
    // (799) + (1999*2) = 4797 ; mrp 999 + 2999*2 = 6997.
    expect(find.byKey(const ValueKey('bag_total_4797')),
        findsOneWidget);
    expect(find.textContaining('2,200'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Stepper inc dec remove update UI', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('bag_inc_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('bag_qty_${_p1.id}_2')),
        findsOneWidget);

    await tester.tap(find.byKey(ValueKey('bag_dec_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('bag_qty_${_p1.id}_1')),
        findsOneWidget);

    await tester.tap(find.byKey(ValueKey('bag_remove_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('bag_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Savings banner shows math + ticks', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    CartStore.instance.increment(_p2.id);
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('bag_savings')),
      find.byKey(const ValueKey('bag_lines')),
      const Offset(0, -500),
    );
    await _settle(tester);
    // save 200 + 2000 = 2200 ; mrp 6997 → 31%.
    expect(find.byKey(const ValueKey('bag_savings')), findsOneWidget);
    expect(find.text('You save ₹2,200 (31%)'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(ValueKey('bag_inc_${_p1.id}')),
      find.byKey(const ValueKey('bag_lines')),
      const Offset(0, 500),
    );
    await _settle(tester);
    await tester.tap(find.byKey(ValueKey('bag_inc_${_p1.id}')));
    await _settle(tester);
    expect(find.textContaining('You save'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Empty bag hides savings banner', (tester) async {
    await _pumpBag(tester);

    expect(find.byKey(const ValueKey('bag_savings')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Place order without address asks for address',
      (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    expect(find.textContaining('fill your address'),
        findsWidgets);
    // 14 full screen opens (not the sheet).
    expect(find.byKey(const ValueKey('addr_screen')),
        findsOneWidget);
    expect(find.text('Select Address'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Shop now calls back', (tester) async {
    var called = false;
    await _pumpBag(tester, onShopNow: () => called = true);

    await tester.tap(find.byKey(const ValueKey('bag_shop_now')));
    await _settle(tester);
    expect(called, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bag 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      CartStore.resetForTests();
      CartStore.instance.add(_p1);
      CartStore.instance.add(_p2);
      await tester.pumpWidget(
          MaterialApp(home: BagScreen(onShopNow: () {})));
      await _settle(tester);
      // Scroll end-to-end so lazy rows + bill + banner all lay out.
      final scroll = find.byKey(const ValueKey('bag_lines'));
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('bag_savings')),
        scroll,
        const Offset(0, -500),
      );
      await _settle(tester);
      await tester.drag(scroll, const Offset(0, 2000));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('Premium bill rows tick + flash on qty change',
      (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    await _settle(tester);

    // mrp 999+2999=3998 ; save 200+1000=1200 ; pay 2798.
    expect(find.byKey(const ValueKey('bag_bill_count_2')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('billflash_mrp_3998')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('billflash_disc_1400')),
        findsNothing);
    expect(find.byKey(const ValueKey('billflash_disc_1200')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('bag_total_2798')),
        findsOneWidget);
    expect(find.text('BEST DEAL • on this order'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('bag_inc_${_p1.id}')));
    await _settle(tester);
    // mrp 4997 ; save 1400 ; pay 3597 — rows re-key + tick.
    expect(find.byKey(const ValueKey('bag_bill_count_3')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('billflash_mrp_4997')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('billflash_disc_1400')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('bag_total_3597')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('save_1400')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
