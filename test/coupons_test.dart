import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/coupons/data/coupon_store.dart';
import 'package:oxro/features/coupons/presentation/screens/coupons_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';

const _p = Product(
  id: 4001,
  name: 'Coupon Tee',
  brand: 'OXRO',
  price: 1000,
  mrp: 1500,
  rating: 4.3,
  reviews: 120,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);

const _addr = Address(
  id: 'c1',
  label: 'Home',
  name: 'Test User',
  phone: '9876543210',
  line: '123 Main Street',
  city: 'Chennai',
  pin: '600001',
);

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
    CartStore.resetForTests();
    AddressStore.resetForTests();
    PaymentStore.resetForTests();
  });

  test('byCode + discount math + ranking', () {
    expect(CouponStore.byCode('oxro500')?.code, 'OXRO500');
    expect(CouponStore.byCode(' nope '), isNull);

    final oxro = CouponStore.byCode('OXRO500')!;
    expect(oxro.discountFor(2000), 0); // below min
    expect(oxro.discountFor(3000), 500);

    final welcome = CouponStore.byCode('WELCOME10')!;
    expect(welcome.discountFor(500), 0);
    expect(welcome.discountFor(1000), 100);
    expect(welcome.discountFor(10000), 300); // capped

    // Best first on 4000: OXRO500 (500) beats WELCOME10 (300 cap).
    final ranked = CouponStore.eligibleFor(4000);
    expect(ranked.first.code, 'OXRO500');
    // Small cart: only FREESHIP.
    expect(
        CouponStore.eligibleFor(600).map((c) => c.code), ['FREESHIP']);
  });

  test('FREESHIP waives shipping in toPay', () {
    CartStore.instance.add(_p); // 1000
    expect(PaymentStore.instance.applyCoupon('FREESHIP'), isTrue);
    expect(PaymentStore.instance.freeShip, isTrue);
    expect(PaymentStore.instance.toPay, 1000);
    PaymentStore.instance.clearCoupon();
    expect(PaymentStore.instance.freeShip, isFalse);
    expect(PaymentStore.instance.toPay,
        1000 + PaymentStore.shippingFee);
  });

  testWidgets('Coupons screen applies + pops', (tester) async {
    CartStore.instance.add(_p);
    CartStore.instance.add(_p);
    CartStore.instance.add(_p);
    CartStore.instance.add(_p); // 4000
    await tester.pumpWidget(
        const MaterialApp(home: CouponsScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('coupons_scroll')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('coupon_card_OXRO500')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('coupon_apply_OXRO500')));
    await _settle(tester);
    expect(PaymentStore.instance.coupon, 'OXRO500');
    expect(PaymentStore.instance.discount, 500);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout offers link opens coupons', (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(
        const MaterialApp(home: CheckoutScreen()));
    await _settle(tester);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('coupon_offers_link')),
      300,
    );
    await _settle(tester);
    await tester.tap(
        find.byKey(const ValueKey('coupon_offers_link')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('coupons_scroll')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Coupons 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      CartStore.resetForTests();
      CartStore.instance.add(_p);
      await tester.pumpWidget(
          const MaterialApp(home: CouponsScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'coupons at $size');
      await _dispose(tester);
    }
  });
}
