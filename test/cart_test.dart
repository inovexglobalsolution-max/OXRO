import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/app/data/delivery_schedule.dart';
import 'package:oxro/app/widgets/add_button.dart';
import 'package:oxro/app/widgets/dish_card.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/detail/data/product_sizes.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';
import 'package:oxro/features/restaurants/presentation/screens/restaurant_screen.dart';

const _p1 = Product(
  id: 101,
  name: 'Test Shirt',
  brand: 'OXRO',
  price: 799,
  mrp: 999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);
const _p2 = Product(
  id: 102,
  name: 'Test Shoes',
  brand: 'Nike',
  price: 1999,
  mrp: 2999,
  rating: 4.5,
  reviews: 200,
  icon: Icons.directions_run,
  colors: [Colors.white, Colors.black],
);

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(CartStore.resetForTests);

  // ---- Store unit tests ----
  test('Cart add/qty/totals/remove/clear', () {
    final cart = CartStore.instance;
    expect(cart.count, 0);
    expect(cart.contains(101), isFalse);

    cart.add(_p1);
    expect(cart.qty(101), 1);
    expect(cart.count, 1);
    expect(cart.distinct, 1);

    cart.add(_p1);
    cart.add(_p2);
    expect(cart.qty(101), 2);
    expect(cart.count, 3);
    expect(cart.distinct, 2);
    expect(cart.totalPrice, 799 * 2 + 1999);
    expect(cart.totalMrp, 999 * 2 + 2999);
    expect(cart.savings, cart.totalMrp - cart.totalPrice);

    cart.increment(102);
    expect(cart.qty(102), 2);
    cart.decrement(102);
    expect(cart.qty(102), 1);
    cart.decrement(102);
    expect(cart.contains(102), isFalse);

    cart.remove(101);
    expect(cart.count, 0);
    cart.add(_p1);
    cart.clear();
    expect(cart.count, 0);
    expect(cart.lines, isEmpty);
  });

  test('Cart notifies listeners', () {
    final cart = CartStore.instance;
    var calls = 0;
    void listener() => calls++;
    cart.addListener(listener);
    cart.add(_p1);
    cart.increment(101);
    cart.decrement(101);
    cart.remove(999); // no-op, no notify
    cart.clear();
    expect(calls, 4);
    cart.removeListener(listener);
  });

  test('Size catalogue: dresses, shoes, one-size', () {
    expect(sizeTypeFor(_p1), SizeType.apparel);
    expect(sizesFor(_p1), ['S', 'M', 'L', 'XL', 'XXL']);
    expect(requiresSize(_p1), isTrue);
    expect(defaultSizeFor(_p1), 'M');

    expect(sizeTypeFor(_p2), SizeType.footwear);
    expect(sizesFor(_p2), ['UK 6', 'UK 7', 'UK 8', 'UK 9', 'UK 10', 'UK 11']);
    expect(requiresSize(_p2), isTrue);
    expect(defaultSizeFor(_p2), 'UK 9');

    const tv = Product(
      id: 103,
      name: 'LED TV 43 inch',
      brand: 'Mi',
      price: 24999,
      mrp: 32999,
      rating: 4.4,
      reviews: 500,
      icon: Icons.tv,
      colors: [Colors.white, Colors.black],
    );
    expect(sizeTypeFor(tv), SizeType.oneSize);
    expect(sizesFor(tv), isEmpty);
    expect(requiresSize(tv), isFalse);
    expect(defaultSizeFor(tv), isNull);
  });

  test('Cart splits same product by size', () {
    final cart = CartStore.instance;
    cart.add(_p1, size: 'M');
    cart.add(_p1, size: 'L');
    cart.add(_p1, size: 'M');
    expect(cart.qty(101), 3);
    expect(cart.qtyOf(101, 'M'), 2);
    expect(cart.qtyOf(101, 'L'), 1);
    expect(cart.distinct, 2);

    cart.increment(101, size: 'L');
    expect(cart.qtyOf(101, 'L'), 2);
    cart.decrement(101, size: 'M');
    expect(cart.qtyOf(101, 'M'), 1);

    cart.remove(101, size: 'L');
    expect(cart.qtyOf(101, 'L'), 0);
    expect(cart.qty(101), 1);
    expect(cart.contains(101), isTrue);
    cart.remove(101);
    expect(cart.contains(101), isFalse);
  });

  test('Per-line schedules persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final cart = CartStore.instance;
    final mSchedule = DeliverySchedule(
      date: DateTime(2026, 12, 1),
      dayLabel: 'Today',
      slot: '7:00 PM – 7:30 PM',
    );
    final lSchedule = DeliverySchedule(
      date: DateTime(2026, 12, 2),
      dayLabel: 'Tomorrow',
      slot: '8:00 PM – 8:30 PM',
    );

    cart.add(_p1, size: 'M');
    cart.add(_p1, size: 'L');
    cart.setSchedule(101, size: 'M', schedule: mSchedule);
    cart.setSchedule(101, size: 'L', schedule: lSchedule);
    expect(cart.lines.length, 2);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    CartStore.resetForTests();
    await CartStore.instance.load();

    final mLine = CartStore.instance.lines.firstWhere(
      (line) => line.size == 'M',
    );
    final lLine = CartStore.instance.lines.firstWhere(
      (line) => line.size == 'L',
    );
    expect(mLine.schedule, mSchedule);
    expect(lLine.schedule, lSchedule);

    CartStore.instance.remove(101, size: 'M');
    expect(CartStore.instance.lines.single.schedule, lSchedule);

    CartStore.instance.clear();
    expect(CartStore.instance.lines, isEmpty);
    expect(
      DeliverySchedule.tryFromJson({'date': 'bad', 'dayLabel': '', 'slot': ''}),
      isNull,
    );
  });

  // ---- Widget tests ----
  testWidgets('PLP card ADD morphs to stepper and back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductListingScreen(
          title: 'T',
          leafs: const ['Shirts'],
          icon: Icons.checkroom_outlined,
        ),
      ),
    );
    await _frames(tester);

    final before = find.text('ADD').evaluate().length;
    expect(before, greaterThan(0));
    await tester.tap(find.text('ADD').first);
    await _frames(tester, 3);
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await _frames(tester, 3);
    // One card flipped to stepper, rest still ADD.
    expect(CartStore.instance.count, 1);
    expect(find.text('ADD').evaluate().length, before - 1);
    expect(find.text('+'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Stepper + and - change qty', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final r = RestaurantRepo.all.first;
    final dish = r.dishes.first;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _frames(tester);

    final add = find.byKey(ValueKey('food_add_${dish.id}'));
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await tester.pumpAndSettle();
    expect(CartStore.instance.qty(dish.id), 1);

    final stepper = find.byKey(ValueKey('food_stepper_${dish.id}'));
    await tester.tap(find.descendant(of: stepper, matching: find.text('+')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(CartStore.instance.qty(dish.id), 2);

    await tester.tap(find.descendant(of: stepper, matching: find.text('−')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(of: stepper, matching: find.text('−')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(CartStore.instance.qty(dish.id), 0);
    expect(find.byKey(ValueKey('food_add_${dish.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Card ADD opens dish customization before adding', (
    tester,
  ) async {
    final dish = RestaurantRepo.all
        .expand((r) => r.dishes)
        .firstWhere((d) => d.options.isNotEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 320,
              child: DishCard(product: dish, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(ValueKey('add_${dish.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('customize_add')), findsOneWidget);
    expect(CartStore.instance.count, 0);

    await tester.tap(find.byKey(const ValueKey('customize_plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await tester.pumpAndSettle();

    expect(CartStore.instance.qty(dish.id), 2);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bag badge follows cart count', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Empty cart → no badge.
    expect(find.byKey(const ValueKey('bag_badge_count')), findsNothing);

    CartStore.instance.add(_p1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('bag_badge_count')), findsWidgets);
    expect(
      (tester.widgetList(find.byKey(const ValueKey('bag_badge_count'))).first
              as Text)
          .data,
      '1',
    );

    CartStore.instance.increment(_p1.id);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widgetList(find.byKey(const ValueKey('bag_badge_count')))
          .map((w) => (w as Text).data)
          .toSet(),
      {'2'},
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('AddButton standalone shows ADD then stepper', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AddButton(product: _p1)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('ADD'), findsOneWidget);
    await tester.tap(find.text('ADD'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('1'), findsOneWidget);
    expect(CartStore.instance.qty(101), 1);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Restaurant cart bar hides empty, then opens Bag', (
    tester,
  ) async {
    final r = RestaurantRepo.all.first;
    final dish = r.dishes.first;
    await tester.pumpWidget(
      MaterialApp(home: RestaurantScreen(restaurantId: r.id)),
    );
    await _frames(tester);

    // Empty bag → bar hidden.
    expect(find.byKey(const ValueKey('restaurant_cart_bar')), findsNothing);

    final add = find.byKey(ValueKey('food_add_${dish.id}'));
    await tester.ensureVisible(add);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('restaurant_cart_bar')), findsOneWidget);
    expect(find.text('VIEW CART'), findsOneWidget);
    expect(
      find.text('1 item · ${Product.inr(CartStore.instance.totalPrice)}'),
      findsOneWidget,
    );
    expect(find.textContaining('Â'), findsNothing);
    expect(find.textContaining('â'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('restaurant_cart_bar')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('My Cart'), findsOneWidget);
    expect(find.byKey(const ValueKey('restaurant_cart_bar')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
