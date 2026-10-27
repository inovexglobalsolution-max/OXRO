import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/data/delivery_schedule.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_gateway.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/restaurants/data/restaurant_repo.dart';

const _p = Product(
  id: 901,
  name: 'Checkout Shirt',
  brand: 'OXRO',
  restaurantId: 'R-CHECKOUT',
  restaurantName: 'Checkout Kitchen',
  price: 799,
  mrp: 999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);

const _small = Product(
  id: 902,
  name: 'Mini Combo',
  brand: 'OXRO',
  restaurantId: 'R-CHECKOUT',
  restaurantName: 'Checkout Kitchen',
  price: 42,
  mrp: 60,
  rating: 4.1,
  reviews: 40,
  icon: Icons.rice_bowl,
  colors: [Colors.orange, Colors.deepOrange],
);

const _addr = Address(
  id: 'home1',
  label: 'Home',
  name: 'Sachin V',
  phone: '9876543210',
  line: '123, Anna Nagar',
  city: 'Chennai',
  pin: '600040',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(() {
    CartStore.resetForTests();
    AddressStore.resetForTests();
    PaymentStore.resetForTests();
    OrderStore.resetForTests();
  });

  test('Address validation + hasValid', () {
    expect(AddressStore.validateName(''), isNotNull);
    expect(AddressStore.validateName('Ab'), isNotNull);
    expect(AddressStore.validateName('Sachin V'), isNull);
    expect(AddressStore.validatePhone('123'), isNotNull);
    expect(AddressStore.validatePhone('9876543210'), isNull);
    expect(AddressStore.validatePin('123'), isNotNull);
    expect(AddressStore.validatePin('600040'), isNull);
    expect(AddressStore.instance.hasValid, isFalse);
    AddressStore.instance.save(_addr);
    expect(AddressStore.instance.hasValid, isTrue);
    expect(AddressStore.instance.displayLine, contains('600040'));
  });

  test('Address issue flags missing, door and details', () {
    AddressStore.resetForTests();
    expect(AddressStore.instance.issue, AddressIssue.missing);

    AddressStore.instance.add(
      const Address(
        id: 'door',
        label: 'Home',
        name: 'Sachin V',
        phone: '9876543210',
        line: '',
        city: 'Chennai',
        pin: '600040',
      ),
    );
    expect(AddressStore.instance.issue, AddressIssue.doorMissing);

    AddressStore.resetForTests();
    AddressStore.instance.add(
      const Address(
        id: 'details',
        label: 'Home',
        name: 'Sachin V',
        phone: '9876543210',
        line: '123, Anna Nagar',
        city: 'Chennai',
        pin: '12',
      ),
    );
    expect(AddressStore.instance.issue, AddressIssue.incomplete);

    AddressStore.instance.add(_addr);
    expect(AddressStore.instance.issue, AddressIssue.none);
    expect(AddressStore.instance.hasValid, isTrue);
  });

  test('Payment totals + coupon', () {
    CartStore.instance.add(_p);
    expect(PaymentStore.instance.itemsTotal, 799);
    // items 79900 + delivery 4000 + platform 200 + 5% GST 3995.
    expect(PaymentStore.instance.toPayPaise, 88095);
    expect(PaymentStore.instance.applyCoupon('bad'), isFalse);
    // OXRO500 needs Rs.2,999+ cart: rejected on 799.
    expect(PaymentStore.instance.applyCoupon('oxro500'), isFalse);
    // FREESHIP works on 799 (min 499): ship waived.
    expect(PaymentStore.instance.applyCoupon('freeship'), isTrue);
    expect(PaymentStore.instance.freeShip, isTrue);
    // delivery waived: 79900 + 200 + 3995.
    expect(PaymentStore.instance.toPayPaise, 84095);
    PaymentStore.instance.clearCoupon();
    expect(PaymentStore.instance.discount, 0);
    expect(PaymentStore.instance.freeShip, isFalse);
    // Grow cart past 2,999: OXRO500 applies.
    CartStore.instance.add(_p);
    CartStore.instance.add(_p);
    CartStore.instance.add(_p);
    expect(PaymentStore.instance.itemsTotal, 799 * 4);
    expect(PaymentStore.instance.applyCoupon('oxro500'), isTrue);
    expect(PaymentStore.instance.discount, 500);
    // 319600 + 4000 + 200 + 15980 - 50000.
    expect(PaymentStore.instance.toPayPaise, 289780);
    PaymentStore.instance.clearCoupon();
    expect(PaymentStore.instance.discount, 0);
  });

  testWidgets('Bag without address pops message, opens 14 after confirm', (
    tester,
  ) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('address_gate_missing')), findsOneWidget);
    expect(find.text('Add your address first'), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_screen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('address_gate_primary')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout renders summary + pay methods', (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    expect(find.byKey(const ValueKey('checkout_summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay_upi')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay_cod')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('coupon_offers_link')),
      300,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('coupon_offers_link')), findsOneWidget);
    expect(find.byKey(const ValueKey('coupon_field')), findsNothing);
    expect(find.byKey(const ValueKey('coupon_apply')), findsNothing);
    expect(find.byKey(const ValueKey('checkout_place_order')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout_schedules')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout shows, edits and clears per-dish schedules', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DeliverySchedule(
      date: now,
      dayLabel: 'Today',
      slot: '7:00 PM – 7:30 PM',
    );
    final tomorrow = DeliverySchedule(
      date: now.add(const Duration(days: 1)),
      dayLabel: 'Tomorrow',
      slot: '8:00 PM – 8:30 PM',
    );
    CartStore.instance.add(_p);
    CartStore.instance.add(_small);
    CartStore.instance.setSchedule(_p.id, schedule: today);
    CartStore.instance.setSchedule(_small.id, schedule: tomorrow);
    AddressStore.instance.save(_addr);

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    final card = find.byKey(const ValueKey('checkout_schedules'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Scheduled items')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Today · 7:00 PM – 7:30 PM'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Tomorrow · 8:00 PM – 8:30 PM'),
      ),
      findsOneWidget,
    );
    final totalBefore = PaymentStore.instance.quote.grandTotalPaise;

    await tester.scrollUntilVisible(
      find.byKey(ValueKey('checkout_schedule_clear_${_p.id}')),
      300,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(ValueKey('checkout_schedule_clear_${_p.id}')));
    await _frames(tester);

    expect(
      CartStore.instance.lines
          .firstWhere((line) => line.product.id == _p.id)
          .schedule,
      isNull,
    );
    expect(
      CartStore.instance.lines
          .firstWhere((line) => line.product.id == _small.id)
          .schedule,
      tomorrow,
    );
    expect(find.byKey(ValueKey('checkout_schedule_${_p.id}')), findsNothing);
    expect(
      PaymentStore.instance.quote.grandTotalPaise,
      totalBefore,
      reason: 'schedules never affect pricing',
    );

    await tester.scrollUntilVisible(
      find.byKey(ValueKey('checkout_schedule_${_small.id}')),
      300,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(ValueKey('checkout_schedule_${_small.id}')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('schedule_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule_date_2')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_slot_0')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('schedule_confirm')));
    await _settle(tester);
    final edited = CartStore.instance.lines
        .firstWhere((line) => line.product.id == _small.id)
        .schedule;
    expect(edited, isNotNull);
    expect(edited, isNot(tomorrow));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Small cart fee shows separately and snapshots', (tester) async {
    CartStore.instance.add(_small);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    final q = PaymentStore.instance.quote;
    expect(q.smallCartFeePaise, 2000);
    expect(q.grandTotalPaise, 10610);
    expect(find.text('Small cart fee'), findsOneWidget);
    expect(find.text('₹20'), findsWidgets);
    expect(
      find.text('Add ₹57 more to remove the small cart fee!'),
      findsOneWidget,
    );
    expect(find.text('Product discount'), findsOneWidget);
    expect(find.text('−₹18'), findsOneWidget);
    expect(find.text('Already applied to the item total.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('checkout_place_order')));
    await _frames(tester, 3);
    final bill = OrderStore.instance.all.first.bill!;
    expect(bill.smallCartFeePaise, 2000);
    expect(bill.grandTotalPaise, 10610);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout waives the small cart fee from ₹99', (tester) async {
    CartStore.instance.add(_small);
    CartStore.instance.increment(_small.id);
    CartStore.instance.increment(_small.id);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    final q = PaymentStore.instance.quote;
    expect(q.itemSubtotalPaise, 12600);
    expect(q.smallCartFeePaise, 0);
    expect(find.text('Small cart fee'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout_smallcart_hint')), findsNothing);
    expect(find.text('FREE'), findsWidgets);
    expect(find.text('Product discount'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout shows applied coupon chip and removes it', (
    tester,
  ) async {
    for (var i = 0; i < 4; i++) {
      CartStore.instance.add(_p);
    }
    AddressStore.instance.save(_addr);
    expect(PaymentStore.instance.applyCoupon('OXRO500'), isTrue);

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('checkout_applied_coupon')),
      300,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('checkout_applied_coupon')),
      findsOneWidget,
    );
    expect(find.text('Coupon OXRO500'), findsWidgets);
    expect(find.textContaining('You save'), findsOneWidget);
    expect(find.byKey(const ValueKey('coupon_field')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('checkout_coupon_remove')));
    await _frames(tester);
    expect(PaymentStore.instance.coupon, isEmpty);
    expect(find.byKey(const ValueKey('checkout_applied_coupon')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout blocks order without address and opens 14', (
    tester,
  ) async {
    CartStore.instance.add(_p);
    final before = OrderStore.instance.all.length;
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    await tester.tap(find.byKey(const ValueKey('checkout_place_order')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('address_gate_missing')), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_screen')), findsNothing);
    expect(OrderStore.instance.all.length, before);

    await tester.tap(find.byKey(const ValueKey('address_gate_primary')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('COD place order shows green tick then opens tracking', (
    tester,
  ) async {
    CartStore.instance.add(_p);
    CartStore.instance.setInstructions('Less spicy, please');
    CartStore.instance.setCutlery(true);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    await tester.tap(find.byKey(const ValueKey('checkout_place_order')));
    await _frames(tester, 3);
    expect(find.byKey(const ValueKey('payment_success_tick')), findsOneWidget);
    expect(find.text('Payment Successful!'), findsOneWidget);
    expect(find.byKey(const ValueKey('payment_order_id')), findsOneWidget);
    expect(find.byKey(const ValueKey('result_auto_bar')), findsOneWidget);
    // Cart cleared on order.
    expect(CartStore.instance.count, 0);

    // Auto-advance to live tracking after 2s (no tap).
    await tester.pump(const Duration(milliseconds: 2100));
    await _frames(tester, 5);
    expect(find.byKey(const ValueKey('track_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_header')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_restaurant')), findsOneWidget);
    expect(find.textContaining('Checkout Kitchen'), findsOneWidget);
    // The removed Order Placed page never appears.
    expect(find.text('Order Placed!'), findsNothing);

    // Details from tracking shows the real snapshot (not unavailable).
    final viewOrder = find.byKey(const ValueKey('track_view_order'));
    await Scrollable.ensureVisible(tester.element(viewOrder), alignment: 0.5);
    await _settle(tester);
    await tester.tap(viewOrder);
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_screen')), findsOneWidget);
    expect(find.text('Checkout Shirt'), findsOneWidget);
    expect(find.byKey(const ValueKey('details_restaurant')), findsOneWidget);
    expect(find.text('Checkout Kitchen'), findsOneWidget);
    expect(find.textContaining('snapshot unavailable'), findsNothing);
    expect(find.byKey(const ValueKey('details_food_prefs')), findsOneWidget);
    expect(find.text('Less spicy, please'), findsOneWidget);
    expect(find.text('Cutlery opted in'), findsOneWidget);
    final placed = OrderStore.instance.all.first;
    expect(placed.restaurantId, 'R-CHECKOUT');
    expect(placed.restaurantName, 'Checkout Kitchen');
    expect(placed.instructions, 'Less spicy, please');
    expect(placed.cutleryOptIn, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('UPI failure then retry succeeds', (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    PaymentGateway.instance.failNextForTests();
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    await tester.tap(find.byKey(const ValueKey('checkout_place_order')));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const ValueKey('payment_failed')), findsOneWidget);
    expect(find.textContaining('could not be completed'), findsWidgets);
    expect(CartStore.instance.count, 1);

    await tester.tap(find.byKey(const ValueKey('payment_retry')));
    await tester.pump(const Duration(milliseconds: 1500));
    await _frames(tester, 5);
    expect(find.byKey(const ValueKey('payment_success_tick')), findsOneWidget);
    expect(find.text('Payment Successful!'), findsOneWidget);
    // Cart cleared on order.
    expect(CartStore.instance.count, 0);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout shows bill summary, distance and gratitude art', (
    tester,
  ) async {
    final restaurant = RestaurantRepo.all.first;
    CartStore.instance.add(restaurant.menu.first.dishes.first);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    expect(find.text('Bill Summary'), findsOneWidget);
    expect(
      find.textContaining('Delivery partner fee · ${restaurant.distanceLabel}'),
      findsOneWidget,
    );
    expect(
      find.text('Goes to them for their time and effort.'),
      findsOneWidget,
    );
    // No coupon applied yet → no coupon row in the bill.
    expect(find.text('Coupon Discount'), findsNothing);
    expect(find.byKey(const ValueKey('gratitude_art')), findsOneWidget);
    expect(find.text('GRATITUDE CORNER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Other tip dialog applies a custom amount', (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);
    final before = PaymentStore.instance.toPay;
    await tester.ensureVisible(find.byKey(const ValueKey('tip_other')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('tip_other')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('tip_custom_dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('tip_custom_field')),
      '75',
    );
    await tester.tap(find.byKey(const ValueKey('tip_custom_apply')));
    await _settle(tester);

    expect(PaymentStore.instance.tip, 75);
    expect(PaymentStore.instance.toPay, before + 75);
    expect(find.text('₹75'), findsWidgets);
    expect(find.text('Delivery partner tip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      CartStore.resetForTests();
      AddressStore.resetForTests();
      PaymentStore.resetForTests();
      CartStore.instance.add(_p);
      CartStore.instance.setSchedule(
        _p.id,
        schedule: DeliverySchedule(
          date: DateTime.now().add(const Duration(days: 1)),
          dayLabel: 'Tomorrow',
          slot: '8:00 PM – 8:30 PM',
        ),
      );
      AddressStore.instance.save(_addr);
      await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
      await _frames(tester, 4);
      expect(find.byKey(const ValueKey('checkout_schedules')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  testWidgets('Small cart hint fits 320', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CartStore.instance.add(_small);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester, 4);

    expect(
      find.byKey(const ValueKey('checkout_smallcart_hint')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  test('Multi-address Home/Office CRUD + default', () {
    AddressStore.resetForTests();
    expect(AddressStore.instance.hasAny, isFalse);
    final homeId = AddressStore.instance.add(_addr);
    final officeId = AddressStore.instance.add(
      const Address(
        id: '',
        label: 'Office',
        name: 'Priya S',
        phone: '9765432108',
        line: '45, Guindy',
        city: 'Chennai',
        pin: '600032',
      ),
    );
    expect(AddressStore.instance.items.length, 2);
    // Latest valid add becomes default.
    expect(AddressStore.instance.defaultId, officeId);
    AddressStore.instance.select(homeId);
    expect(AddressStore.instance.defaultId, homeId);
    expect(AddressStore.instance.hasValid, isTrue);
    AddressStore.instance.remove(homeId);
    expect(AddressStore.instance.items.length, 1);
    expect(AddressStore.instance.defaultId, officeId);
  });

  testWidgets('14 screen shows cards + add + continue guard', (tester) async {
    AddressStore.resetForTests();
    await tester.pumpWidget(const MaterialApp(home: AddressSelectionScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(find.text('Select Address'), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_add')), findsOneWidget);
    // Empty continue → popup + stays.
    await tester.tap(find.byKey(const ValueKey('addr_continue')));
    await _settle(tester);
    expect(find.textContaining('fill your address'), findsWidgets);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);

    // Add one address via store → card + radio appear.
    AddressStore.instance.add(_addr);
    await _settle(tester);
    expect(find.byKey(ValueKey('addr_card_${_addr.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('addr_radio_${_addr.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('14 screen 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    AddressStore.resetForTests();
    AddressStore.instance.add(_addr);
    await tester.pumpWidget(const MaterialApp(home: AddressSelectionScreen()));
    await _frames(tester, 4);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
