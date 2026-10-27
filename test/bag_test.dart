import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';

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
const _small = Product(
  id: 204,
  name: 'Mini Samosa',
  brand: 'Paradise Biryani',
  restaurantId: 'r_paradise',
  restaurantName: 'Paradise Biryani',
  price: 45,
  mrp: 60,
  rating: 4.4,
  reviews: 80,
  icon: Icons.rice_bowl_outlined,
  colors: [Colors.orange, Colors.deepOrange],
);
const _belowMin = Product(
  id: 203,
  name: 'Special Chicken Biryani',
  brand: 'Paradise Biryani',
  restaurantId: 'r_paradise',
  restaurantName: 'Paradise Biryani',
  price: 169,
  mrp: 248,
  rating: 4.5,
  reviews: 100,
  icon: Icons.rice_bowl_outlined,
  colors: [Colors.orange, Colors.deepOrange],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _pumpBag(WidgetTester tester, {VoidCallback? onShopNow}) async {
  CartStore.resetForTests();
  PaymentStore.resetForTests();
  PremiumStore.resetForTests();
  AddressStore.resetForTests();
  await tester.pumpWidget(
    MaterialApp(home: BagScreen(onShopNow: onShopNow ?? () {})),
  );
  await _settle(tester);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byKey(const ValueKey('bag_lines')),
    const Offset(0, -260),
  );
  await _settle(tester);
}

Future<Finder> _revealBill(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('bag_bill_toggle'));
  await tester.dragUntilVisible(
    toggle,
    find.byKey(const ValueKey('bag_lines')),
    const Offset(0, -260),
  );
  await _settle(tester);
  return toggle;
}

Future<void> _expandBill(WidgetTester tester) async {
  final toggle = await _revealBill(tester);
  await tester.drag(
    find.byKey(const ValueKey('bag_lines')),
    const Offset(0, -120),
  );
  await _settle(tester);
  await tester.tap(toggle);
  await _settle(tester);
}

Future<void> _toTop(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('bag_lines')),
    const Offset(0, 2400),
  );
  await _settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CartStore.resetForTests();
    PaymentStore.resetForTests();
    PremiumStore.resetForTests();
    AddressStore.resetForTests();
  });

  testWidgets('Empty bag shows CTA', (tester) async {
    await _pumpBag(tester);

    expect(find.byKey(const ValueKey('bag_empty')), findsOneWidget);
    expect(find.text('Your bag is empty'), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_shop_now')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Back button falls back to Home on root bag', (tester) async {
    var wentHome = 0;
    await _pumpBag(tester, onShopNow: () => wentHome++);

    expect(find.byKey(const ValueKey('bag_back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bag_back')));
    await _settle(tester);
    expect(wentHome, 1);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Back button pops a pushed bag', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey('open_bag'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BagScreen(onShopNow: () {}),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('open_bag')));
    await _settle(tester);
    expect(find.text('My Cart'), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bag_back')));
    await _settle(tester);
    expect(find.text('My Cart'), findsNothing);
    expect(find.byKey(const ValueKey('open_bag')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  test('Small cart fee slabs follow cart value', () {
    for (final (total, fee) in [
      (0, 0),
      (42, 2000),
      (49, 2000),
      (50, 1500),
      (69, 1500),
      (70, 1000),
      (98, 1000),
      (99, 0),
    ]) {
      expect(
        PaymentStore.instance.quoteForItemsTotal(total).smallCartFeePaise,
        fee,
        reason: 'cart ₹$total',
      );
    }
  });

  testWidgets('Small cart hint updates and hides across ₹99', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_small);
    await _settle(tester);

    await _scrollTo(tester, find.byKey(const ValueKey('bag_smallcart_hint')));
    expect(PaymentStore.instance.quote.smallCartFeePaise, 2000);
    expect(
      find.text('Add ₹54 more to remove the small cart fee!'),
      findsOneWidget,
    );

    CartStore.instance.increment(_small.id);
    await _settle(tester);
    expect(PaymentStore.instance.quote.smallCartFeePaise, 1000);
    expect(
      find.text('Add ₹9 more to remove the small cart fee!'),
      findsOneWidget,
    );

    CartStore.instance.increment(_small.id);
    await _settle(tester);
    expect(PaymentStore.instance.quote.smallCartFeePaise, 0);
    expect(find.byKey(const ValueKey('bag_smallcart_hint')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Removing items re-applies the small cart fee', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_small);
    CartStore.instance.increment(_small.id);
    CartStore.instance.increment(_small.id);
    await _settle(tester);

    expect(PaymentStore.instance.quote.smallCartFeePaise, 0);
    expect(find.byKey(const ValueKey('bag_smallcart_hint')), findsNothing);

    CartStore.instance.decrement(_small.id);
    await _settle(tester);
    expect(PaymentStore.instance.quote.smallCartFeePaise, 1000);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_smallcart_hint')));
    expect(
      find.text('Add ₹9 more to remove the small cart fee!'),
      findsOneWidget,
    );

    CartStore.instance.remove(_small.id);
    await _settle(tester);
    expect(find.byKey(const ValueKey('bag_smallcart_hint')), findsNothing);
    expect(find.byKey(const ValueKey('bag_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Restored cart recalculates the small cart fee', (tester) async {
    CartStore.instance.add(_small);
    await tester.pump(const Duration(milliseconds: 50));
    CartStore.resetForTests();
    await CartStore.instance.load();

    expect(CartStore.instance.totalPrice, 45);
    expect(PaymentStore.instance.quote.smallCartFeePaise, 2000);

    await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
    await _settle(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_smallcart_hint')));
    expect(
      find.text('Add ₹54 more to remove the small cart fee!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Small cart shows fee row separately from delivery', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_small);
    await _settle(tester);

    final quote = PaymentStore.instance.quote;
    expect(quote.smallCartFeePaise, 2000);
    expect(
      find.byKey(ValueKey('bag_bar_total_${quote.grandTotalPaise}')),
      findsOneWidget,
    );

    await _expandBill(tester);
    await _scrollTo(
      tester,
      find.byKey(ValueKey('bag_total_${quote.grandTotalPaise}')),
    );
    expect(
      find.byKey(const ValueKey('billflash_smallcart_2000')),
      findsOneWidget,
    );
    expect(find.text('Small cart fee'), findsOneWidget);
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
    expect(find.byKey(ValueKey('bag_line_${_p1.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_line_${_p2.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_savings')), findsOneWidget);
    expect(find.textContaining('You save'), findsWidgets);

    // item 799 + 1999*2 = 4797 ; grand total 507885 paise with delivery/platform/GST.
    await _expandBill(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_total_507885')));
    expect(find.byKey(const ValueKey('bag_total_507885')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('billflash_delivery_4000')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('billflash_platform_200')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('billflash_tax_23985')), findsOneWidget);
    expect(find.text('Product discount'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('billflash_productdisc_2200')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bag_bill_saved')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bill starts collapsed and expands dish-wise totals', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    CartStore.instance.increment(_p2.id);
    await _settle(tester);

    final toggle = await _revealBill(tester);
    expect(toggle, findsOneWidget);
    expect(find.byKey(const ValueKey('bag_bill_details')), findsNothing);
    expect(find.byKey(const ValueKey('bag_total_507885')), findsNothing);
    expect(find.byKey(const ValueKey('bag_bill_saved')), findsOneWidget);

    await _expandBill(tester);
    expect(find.byKey(const ValueKey('bag_bill_details')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_bill_dish_${_p1.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_bill_dish_${_p2.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('billflash_items_479700')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_total_507885')), findsOneWidget);
    expect(find.text('To Pay'), findsWidgets);

    await tester.tap(toggle);
    await _settle(tester);
    expect(find.byKey(const ValueKey('bag_bill_details')), findsNothing);
    expect(find.byKey(const ValueKey('bag_total_507885')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Food cart total matches bottom bar and is non-zero', (
    tester,
  ) async {
    await _pumpBag(tester);
    final restaurant = RestaurantRepo.all.first;
    final dishes = restaurant.dishes.toList();
    final first = dishes[0];
    final second = dishes[1];
    CartStore.instance.add(first);
    CartStore.instance.increment(first.id);
    CartStore.instance.increment(first.id);
    CartStore.instance.add(second);
    await _settle(tester);

    expect(CartStore.instance.totalPrice, greaterThan(0));
    final grand = PaymentStore.instance.quote.grandTotalPaise;
    expect(grand, greaterThan(0));
    expect(find.byKey(ValueKey('bag_bar_total_$grand')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_savings')), findsOneWidget);

    await _expandBill(tester);
    expect(find.byKey(ValueKey('bag_total_$grand')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_bill_dish_${first.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_bill_dish_${second.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Below-minimum food cart still shows a live total', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_belowMin);
    await _settle(tester);

    expect(CartStore.instance.totalPrice, 169);
    expect(CartStore.instance.savings, 79);
    expect(find.byKey(const ValueKey('bag_min_order')), findsOneWidget);
    expect(find.text('Add ₹30 more to place your order'), findsWidgets);

    final quote = PaymentStore.instance.quoteForItemsTotal(169);
    expect(quote.itemSubtotalPaise, 16900);
    expect(quote.deliveryFeePaise, 4000);
    expect(quote.platformFeePaise, 200);
    expect(quote.smallCartFeePaise, 0);
    expect(quote.taxPaise, 845);
    expect(quote.grandTotalPaise, 21945);
    expect(find.byKey(const ValueKey('bag_bar_total_21945')), findsOneWidget);

    await _expandBill(tester);
    expect(find.byKey(const ValueKey('bag_total_21945')), findsOneWidget);
    expect(find.byKey(const ValueKey('billflash_items_16900')), findsOneWidget);
    expect(find.byKey(const ValueKey('billflash_smallcart_0')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Stepper inc dec remove update UI', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('bag_inc_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('bag_qty_${_p1.id}_2')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('bag_dec_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(ValueKey('bag_qty_${_p1.id}_1')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('bag_remove_${_p1.id}')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('bag_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Sized lines show size chip + split rows', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1, size: 'M');
    CartStore.instance.add(_p1, size: 'L');
    await _settle(tester);

    expect(find.byKey(ValueKey('bag_line_${_p1.id}_M')), findsOneWidget);
    expect(find.byKey(ValueKey('bag_line_${_p1.id}_L')), findsOneWidget);
    expect(find.text('Size: M'), findsOneWidget);
    expect(find.text('Size: L'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('bag_inc_${_p1.id}_M')));
    await _settle(tester);
    expect(find.byKey(ValueKey('bag_qty_${_p1.id}_M_2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Food lines schedule independently; non-food has no chip', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_belowMin);
    CartStore.instance.add(_p1);
    await _settle(tester);

    expect(
      find.byKey(ValueKey('bag_schedule_${_belowMin.id}')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('bag_schedule_${_p1.id}')), findsNothing);
    expect(find.text('Schedule time'), findsWidgets);

    await tester.tap(find.byKey(ValueKey('bag_schedule_${_belowMin.id}')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('schedule_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule_date_1')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_slot_0')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_confirm')));
    await _settle(tester);

    final line = CartStore.instance.lines.firstWhere(
      (l) => l.product.id == _belowMin.id,
    );
    final first = line.schedule;
    expect(first, isNotNull);
    expect(first!.dayLabel, 'Tomorrow');
    expect(
      find.descendant(
        of: find.byKey(ValueKey('bag_schedule_${_belowMin.id}')),
        matching: find.textContaining('Tomorrow · '),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('bag_schedule_clear_${_belowMin.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('bag_schedule_${_belowMin.id}')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_date_2')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_slot_0')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_confirm')));
    await _settle(tester);
    expect(line.schedule, isNot(first));
    expect(line.schedule!.dayLabel, isNot('Tomorrow'));

    await tester.tap(
      find.byKey(ValueKey('bag_schedule_clear_${_belowMin.id}')),
    );
    await _settle(tester);
    expect(line.schedule, isNull);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('bag_schedule_${_belowMin.id}')),
        matching: find.text('Schedule time'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Savings banner shows math + ticks', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    CartStore.instance.increment(_p2.id);
    await _settle(tester);

    // save 200 + 2000 = 2200 ; mrp 6997 -> 31%.
    expect(find.byKey(const ValueKey('bag_savings')), findsOneWidget);
    expect(find.textContaining('You save'), findsWidgets);

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

  testWidgets('Place order without address shows popup first', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('address_gate_missing')), findsOneWidget);
    expect(find.text('Add your address first'), findsOneWidget);
    expect(find.textContaining('Add your flat / door number'), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_screen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('address_gate_later')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('addr_screen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('address_gate_primary')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(find.text('Select Address'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Place order with location but no door line shows door popup', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    AddressStore.instance.add(
      const Address(
        id: 'partial',
        label: 'Home',
        name: 'Test User',
        phone: '9876543210',
        line: '',
        city: 'Chennai',
        pin: '600001',
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('address_gate_door')), findsOneWidget);
    expect(find.text('Door number missing'), findsOneWidget);
    expect(
      find.textContaining('flat / door number is missing'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('addr_screen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('address_gate_primary')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Below-min cart still checks address first', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_belowMin);
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('address_gate_missing')), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_screen')), findsNothing);
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

  testWidgets('Premium offer opens membership', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    await _settle(tester);

    expect(find.byKey(const ValueKey('bag_premium_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_premium_cta')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bag_premium_cta')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('premium_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Premium member gets free delivery above threshold', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    PremiumStore.instance.join();
    await _settle(tester);

    expect(find.byKey(const ValueKey('bag_premium_active')), findsOneWidget);
    await _expandBill(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_total_293990')));
    expect(find.byKey(const ValueKey('billflash_delivery_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_total_293990')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Coupon card applies the best eligible offer', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    await _settle(tester);

    final apply = find.byKey(const ValueKey('bag_coupon_apply_WELCOME10'));
    await _scrollTo(tester, apply);
    await tester.tap(apply);
    await _settle(tester);

    expect(PaymentStore.instance.coupon, 'WELCOME10');
    await _expandBill(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_total_269990')));
    expect(find.byKey(const ValueKey('bag_total_269990')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Address card shows saved address and opens selection', (
    tester,
  ) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    AddressStore.instance.add(
      const Address(
        id: '',
        label: 'Home',
        name: 'Test User',
        phone: '9876543210',
        line: '12 Test Street',
        city: 'Chennai',
        pin: '600001',
      ),
    );
    await _settle(tester);

    await _scrollTo(tester, find.byKey(const ValueKey('bag_address')));
    expect(find.text('Delivery at Home'), findsOneWidget);
    expect(find.textContaining('12 Test Street'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bag_address')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Complete meal rail adds a dish from the same kitchen', (
    tester,
  ) async {
    await _pumpBag(tester);
    final restaurant = RestaurantRepo.all.first;
    final inBag = restaurant.dishes.first;
    final addOn = restaurant.dishes.firstWhere((dish) => dish.id != inBag.id);
    CartStore.instance.add(inBag);
    await _settle(tester);

    await _scrollTo(tester, find.byKey(const ValueKey('bag_meal_rail')));
    expect(find.byKey(const ValueKey('bag_meal_rail')), findsOneWidget);
    await _scrollTo(tester, find.byKey(ValueKey('bag_meal_add_${addOn.id}')));
    final before = CartStore.instance.count;
    await tester.tap(find.byKey(ValueKey('bag_meal_add_${addOn.id}')));
    await _settle(tester);

    expect(CartStore.instance.count, before + 1);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Bag 320 + 390 + 768 no overflow', (tester) async {
    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CartStore.resetForTests();
      PaymentStore.resetForTests();
      PremiumStore.resetForTests();
      AddressStore.resetForTests();
      CartStore.instance.add(_p1);
      CartStore.instance.add(_p2);
      await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
      await _settle(tester);
      await _expandBill(tester);
      final scroll = find.byKey(const ValueKey('bag_lines'));
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('bag_cancellation')),
        scroll,
        const Offset(0, -260),
      );
      await _settle(tester);
      await tester.drag(scroll, const Offset(0, 3000));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('Small cart hint fits 320', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpBag(tester);
    CartStore.instance.add(_small);
    await _settle(tester);

    await _scrollTo(tester, find.byKey(const ValueKey('bag_smallcart_hint')));
    expect(find.byKey(const ValueKey('bag_smallcart_hint')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Selected per-dish schedule fits 320', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpBag(tester);
    CartStore.instance.add(_belowMin);
    await _settle(tester);

    final chip = find.byKey(ValueKey('bag_schedule_${_belowMin.id}'));
    await _scrollTo(tester, chip);
    await tester.tap(chip);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_confirm')));
    await _settle(tester);

    expect(
      CartStore.instance.lines.single.schedule,
      isNotNull,
      reason: 'default slot should save at 320',
    );
    expect(
      find.byKey(ValueKey('bag_schedule_clear_${_belowMin.id}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Food cart reference sections fit narrow + tablet', (
    tester,
  ) async {
    for (final size in const [
      Size(320, 640),
      Size(390, 844),
      Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CartStore.resetForTests();
      PaymentStore.resetForTests();
      PremiumStore.resetForTests();
      AddressStore.resetForTests();
      CartStore.instance.add(RestaurantRepo.all.first.dishes.first);
      await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
      await _settle(tester);
      final scroll = find.byKey(const ValueKey('bag_lines'));
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('bag_cancellation')),
        scroll,
        const Offset(0, -260),
      );
      await _settle(tester);
      await tester.drag(scroll, const Offset(0, 4000));
      await _settle(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'food cart overflow at $size',
      );
      await _dispose(tester);
    }
  });

  testWidgets('Premium bill rows tick + flash on qty change', (tester) async {
    await _pumpBag(tester);
    CartStore.instance.add(_p1);
    CartStore.instance.add(_p2);
    await _settle(tester);

    await _expandBill(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_total_297990')));
    // item 799 + 1999 = 2798 ; grand total 297990 paise with delivery/platform/GST.
    expect(find.byKey(const ValueKey('bag_bill_count_2')), findsOneWidget);
    expect(find.byKey(ValueKey('billflash_items_279800')), findsOneWidget);
    expect(find.byKey(ValueKey('billflash_delivery_4000')), findsOneWidget);
    expect(find.byKey(ValueKey('billflash_platform_200')), findsOneWidget);
    expect(find.byKey(ValueKey('billflash_tax_13990')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_total_297990')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_bill_saved')), findsOneWidget);

    await _toTop(tester);
    await tester.tap(find.byKey(ValueKey('bag_inc_${_p1.id}')));
    await _settle(tester);
    await _expandBill(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('bag_total_381885')));
    // item 799*2 + 1999 = 3597 ; grand total 381885 paise; rows re-key + tick.
    expect(find.byKey(const ValueKey('bag_bill_count_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_total_381885')), findsOneWidget);
    expect(find.byKey(const ValueKey('bag_bill_saved')), findsOneWidget);

    await _toTop(tester);
    expect(find.byKey(const ValueKey('save_1400')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
