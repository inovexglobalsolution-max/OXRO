import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/screens/address_selection_screen.dart';
import 'package:oxro/features/checkout/presentation/screens/order_success_screen.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';

const _p = Product(
  id: 901,
  name: 'Checkout Shirt',
  brand: 'OXRO',
  price: 799,
  mrp: 999,
  rating: 4.2,
  reviews: 100,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
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
    expect(AddressStore.instance.displayLine,
        contains('600040'));
  });

  test('Payment totals + coupon', () {
    CartStore.instance.add(_p);
    expect(PaymentStore.instance.itemsTotal, 799);
    expect(PaymentStore.instance.toPay,
        799 + PaymentStore.shippingFee);
    expect(
        PaymentStore.instance.applyCoupon('bad'), isFalse);
    // OXRO500 needs Rs.2,999+ cart: rejected on 799.
    expect(PaymentStore.instance.applyCoupon('oxro500'), isFalse);
    // FREESHIP works on 799 (min 499): ship waived.
    expect(PaymentStore.instance.applyCoupon('freeship'), isTrue);
    expect(PaymentStore.instance.freeShip, isTrue);
    expect(PaymentStore.instance.toPay, 799);
    PaymentStore.instance.clearCoupon();
    expect(PaymentStore.instance.discount, 0);
    expect(PaymentStore.instance.freeShip, isFalse);
    // Grow cart past 2,999: OXRO500 applies.
    CartStore.instance.add(_p);
    CartStore.instance.add(_p);
    CartStore.instance.add(_p);
    expect(PaymentStore.instance.itemsTotal, 799 * 4);
    expect(PaymentStore.instance.applyCoupon('oxro500'),
        isTrue);
    expect(PaymentStore.instance.discount, 500);
    expect(PaymentStore.instance.toPay,
        799 * 4 + PaymentStore.shippingFee - 500);
    PaymentStore.instance.clearCoupon();
    expect(PaymentStore.instance.discount, 0);
  });

  testWidgets('Bag without address pops message + opens 14',
      (tester) async {
    CartStore.instance.add(_p);
    await tester.pumpWidget(
        MaterialApp(home: BagScreen(onShopNow: () {})));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_order')));
    await _settle(tester);
    // Popup + 14 full screen.
    expect(find.textContaining('First fill your address'),
        findsWidgets);
    expect(find.byKey(const ValueKey('addr_screen')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout renders summary + pay methods',
      (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(
        const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    expect(find.byKey(const ValueKey('checkout_summary')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('pay_upi')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('pay_cod')),
        findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('coupon_field')), 300);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('coupon_field')),
        findsOneWidget);
    expect(
        find.byKey(
            const ValueKey('checkout_place_order')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('COD place order auto-moves 16→17 in 2s',
      (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);
    await tester.pumpWidget(
        const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    await tester.tap(find.byKey(
        const ValueKey('checkout_place_order')));
    await _frames(tester, 3);
    expect(
        find.byKey(
            const ValueKey('payment_success_tick')),
        findsOneWidget);
    expect(find.text('Payment Successful!'),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('payment_order_id')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('result_auto_bar')),
        findsOneWidget);
    // Cart cleared on order.
    expect(CartStore.instance.count, 0);

    // Auto-advance after 2s (no tap).
    await tester.pump(const Duration(milliseconds: 2100));
    await _frames(tester, 5);
    expect(find.byKey(const ValueKey('success_box')),
        findsOneWidget);
    expect(find.text('Order Placed!'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('success_track')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('success_track')));
    await _settle(tester);
    // 18 Tracking opens (timeline + ETA).
    expect(find.byKey(const ValueKey('track_screen')),
        findsOneWidget);
    expect(find.text('Track Order'), findsWidgets);
    // Back to 17 → Details shows real snapshot (not unavailable).
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    expect(find.text('Order Placed!'), findsOneWidget);
    final detailsBtn = find.byKey(
        const ValueKey('success_details'));
    await tester.ensureVisible(detailsBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(detailsBtn);
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_screen')),
        findsOneWidget);
    expect(find.text('Checkout Shirt'), findsOneWidget);
    expect(find.textContaining('snapshot unavailable'),
        findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout 320 + 390 no overflow',
      (tester) async {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844)
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      CartStore.resetForTests();
      AddressStore.resetForTests();
      PaymentStore.resetForTests();
      CartStore.instance.add(_p);
      AddressStore.instance.save(_addr);
      await tester.pumpWidget(
          const MaterialApp(home: CheckoutScreen()));
      await _frames(tester, 4);
      expect(tester.takeException(), isNull,
          reason: 'overflow at $size');
      await _dispose(tester);
    }
  });

  test('Multi-address Home/Office CRUD + default', () {
    AddressStore.resetForTests();
    expect(AddressStore.instance.hasAny, isFalse);
    final homeId = AddressStore.instance.add(_addr);
    final officeId = AddressStore.instance.add(const Address(
      id: '',
      label: 'Office',
      name: 'Priya S',
      phone: '9765432108',
      line: '45, Guindy',
      city: 'Chennai',
      pin: '600032',
    ));
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

  testWidgets('14 screen shows cards + add + continue guard',
      (tester) async {
    AddressStore.resetForTests();
    await tester.pumpWidget(const MaterialApp(
        home: AddressSelectionScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('addr_screen')),
        findsOneWidget);
    expect(find.text('Select Address'), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_add')),
        findsOneWidget);
    // Empty continue → popup + stays.
    await tester
        .tap(find.byKey(const ValueKey('addr_continue')));
    await _settle(tester);
    expect(find.textContaining('fill your address'),
        findsWidgets);
    expect(find.byKey(const ValueKey('addr_screen')),
        findsOneWidget);

    // Add one address via store → card + radio appear.
    AddressStore.instance.add(_addr);
    await _settle(tester);
    expect(
        find.byKey(
            ValueKey('addr_card_${_addr.id}')),
        findsOneWidget);
    expect(
        find.byKey(
            ValueKey('addr_radio_${_addr.id}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('14 screen 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    AddressStore.resetForTests();
    AddressStore.instance.add(_addr);
    await tester.pumpWidget(const MaterialApp(
        home: AddressSelectionScreen()));
    await _frames(tester, 4);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('17 success 320 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(
        home: OrderSuccessScreen(orderId: 'OXRO123456')));
    await _frames(tester, 5);
    expect(find.text('Order Placed!'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('success_track')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('success_eta')),
        findsOneWidget);
    // Copy pill works.
    await tester.tap(find.byKey(const ValueKey('success_copy')));
    await _settle(tester);
    expect(find.textContaining('copied'), findsOneWidget);
    // Details link opens 20.
    final detailsBtn = find.byKey(
        const ValueKey('success_details'));
    await tester.ensureVisible(detailsBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(detailsBtn);
    await _settle(tester);
    expect(find.byKey(const ValueKey('details_screen')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
