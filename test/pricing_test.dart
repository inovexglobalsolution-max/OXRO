import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/admin/presentation/screens/admin_pricing_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_pricing.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/pricing/data/pricing_config_store.dart';
import 'package:oxro/features/rider/presentation/screens/rider_offers_screen.dart';
import 'package:oxro/features/seller/presentation/screens/seller_dashboard_screen.dart';

const _p = Product(
  id: 9001,
  name: 'Chicken Biryani',
  brand: 'Anandhas Kitchen',
  price: 300,
  mrp: 360,
  rating: 4.5,
  reviews: 900,
  icon: Icons.rice_bowl,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
);

const _addr = Address(
  id: 'a1',
  label: 'Home',
  name: 'Test User',
  phone: '9876543210',
  line: '12 Fairlands',
  city: 'Salem',
  pin: '636016',
);

Future<void> _frames(WidgetTester tester, [int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CartStore.resetForTests();
    AddressStore.resetForTests();
    PaymentStore.resetForTests();
    OrderStore.resetForTests();
    PricingConfigStore.instance.resetForTests();
  });

  test('admin apply bumps version and records audit', () async {
    final store = PricingConfigStore.instance;
    expect(store.config.commissionBps, 500);
    expect(store.config.version, 1);

    await store.apply(
        store.config.copyWith(commissionBps: 800));

    expect(store.config.commissionBps, 800);
    expect(store.config.version, 2);
    expect(store.audit, isNotEmpty);
    expect(store.audit.first.summary, contains('Commission'));
  });

  test('promo zeroes the customer platform fee', () async {
    final store = PricingConfigStore.instance;
    expect(store.effectivePlatformFeePaise, 200);
    await store.setPromoFreePlatformFee(true);
    expect(store.effectivePlatformFeePaise, 0);
    expect(store.audit.first.summary, contains('promo ON'));
  });

  test('order bill snapshot is frozen across config changes', () async {
    PaymentStore.instance.setTipPaise(1000);
    CartStore.instance.add(_p);
    final q = PaymentStore.instance.quote;
    OrderStore.instance.placeOrder(
      id: 'OXRO-T1',
      products: const [_p],
      bill: OrderBill(
        itemSubtotalPaise: q.itemSubtotalPaise,
        packagingPaise: q.packagingPaise,
        deliveryPaise: q.deliveryFeePaise,
        platformFeePaise: q.platformFeePaise,
        taxPaise: q.taxPaise,
        tipPaise: q.tipPaise,
        discountPaise: q.discountPaise,
        grandTotalPaise: q.grandTotalPaise,
        configVersion: q.configVersion,
      ),
    );
    final frozen = OrderStore.instance.all.first.payablePaise;

    // Admin doubles the platform fee afterwards.
    await PricingConfigStore.instance.apply(PricingConfigStore
        .instance.config
        .copyWith(platformFeePaise: 500));

    expect(OrderStore.instance.all.first.payablePaise, frozen);
    expect(OrderStore.instance.all.first.bill!.configVersion, 1);
  });

  test('checkout quote: 300 order = commission 15 + fee 2', () {
    CartStore.instance.add(_p);
    final q = PaymentStore.instance.quote;
    expect(q.itemSubtotalPaise, 30000);
    expect(q.platformFeePaise, 200);
    expect(q.taxPaise, 1500);
    expect(q.commissionPaise, 1500);
    expect(q.grandTotalPaise,
        30000 + 4000 + 200 + 1500);
  });

  testWidgets('checkout shows platform fee + GST rows',
      (tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(
        const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);
    expect(find.text('Platform fee'), findsOneWidget);
    expect(find.text('GST (govt. taxes)'), findsOneWidget);
    expect(find.text('Delivery partner fee'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seller hub shows net settlement', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SellerDashboardScreen()));
    await _frames(tester);
    expect(find.text('Seller Hub'), findsOneWidget);
    expect(find.textContaining('Net settlement'), findsWidgets);
    expect(find.textContaining('Commission'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rider hub shows earnings before accepting',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: RiderOffersScreen()));
    await _frames(tester);
    expect(find.text('Rider Hub'), findsOneWidget);
    expect(find.textContaining('Estimated earnings'),
        findsWidgets);
    expect(find.text('Base payout'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin save records an audit entry', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: AdminPricingScreen()));
    await _frames(tester);
    expect(find.byKey(const ValueKey('admin_pricing_scroll')),
        findsOneWidget);
    await tester.drag(
        find.byType(Slider).first, const Offset(60, 0));
    await _frames(tester);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('admin_save')), 300);
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('admin_save')));
    await _frames(tester);
    expect(PricingConfigStore.instance.config.version, 2);
    expect(PricingConfigStore.instance.audit, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
