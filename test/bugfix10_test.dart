import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/applock/data/applock_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/listing/data/product_repo.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

const _big = Product(
  id: 9001,
  name: 'Big Tee',
  brand: 'OXRO',
  price: 1000,
  mrp: 1500,
  rating: 4.3,
  reviews: 120,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);

const _addr = Address(
  id: 'b1',
  label: 'Home',
  name: 'Test User',
  phone: '9876543210',
  line: '123 Main Street',
  city: 'Chennai',
  pin: '600001',
);

const _badAddr = Address(
  id: 'b2',
  label: 'Office',
  name: 'Test User',
  phone: '123', // invalid
  line: '456 Side Road',
  city: 'Chennai',
  pin: '600002',
);

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CartStore.resetForTests();
    AddressStore.resetForTests();
    PaymentStore.resetForTests();
    OrderStore.resetForTests();
    WalletStore.resetForTests();
    WishlistStore.resetForTests();
    ProfileStore.resetForTests();
    ApplockStore.resetForTests();
  });

  test('1. Coupon discount recomputes live when cart shrinks', () {
    CartStore.instance.add(_big);
    CartStore.instance.add(_big);
    CartStore.instance.add(_big);
    CartStore.instance.add(_big); // 4000
    expect(PaymentStore.instance.applyCoupon('OXRO500'), isTrue);
    expect(PaymentStore.instance.discount, 500);

    // Shrink below minOrder 2999 → savings auto-invalidate.
    CartStore.instance.decrement(_big.id);
    CartStore.instance.decrement(_big.id);
    CartStore.instance.decrement(_big.id); // 1000
    expect(PaymentStore.instance.discount, 0);
    expect(PaymentStore.instance.coupon, 'OXRO500'); // code kept
    // 100000 + 4000 delivery + 200 platform + 5000 GST.
    expect(PaymentStore.instance.toPayPaise, 109200);
  });

  test('1b. FREESHIP drops when cart falls below minimum', () {
    CartStore.instance.add(_big); // 1000
    expect(PaymentStore.instance.applyCoupon('FREESHIP'), isTrue);
    expect(PaymentStore.instance.freeShip, isTrue);
    CartStore.instance.clear(); // 0
    expect(PaymentStore.instance.freeShip, isFalse);
    // Empty cart: delivery 4000 + platform 200.
    expect(PaymentStore.instance.toPayPaise, 4200);
  });

  testWidgets('2. Empty bag blocks Place Order (no phantom order)',
      (tester) async {
    AddressStore.instance.save(_addr);
    final before = OrderStore.instance.all.length;
    await tester.pumpWidget(
        const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    await tester.tap(find.byKey(
        const ValueKey('checkout_place_order')));
    await _frames(tester);
    expect(find.text('Your bag is empty — add items first'),
        findsOneWidget);
    expect(OrderStore.instance.all.length, before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(Container());
  });

  test('3. Catalogue ids unique across every sub-category', () {
    final ids = <int>{};
    var total = 0;
    for (final cat in foodCategories) {
      for (final sub in subcategoriesFor(cat.label)) {
        for (var i = 0;
            i < ProductRepo.totalPerLeaf;
            i++) {
          ids.add(ProductRepo.productId(
              cat.label, sub, i));
          total++;
        }
      }
    }
    expect(total, greaterThan(1000));
    expect(ids.length, total);
  });

  test('4. Bag/address/wallet/wishlist/coupon survive restart',
      () async {
    CartStore.instance.add(_big);
    CartStore.instance.add(_big);
    AddressStore.instance.save(_addr);
    WalletStore.instance.add(500);
    WishlistStore.instance.toggle(_big);
    PaymentStore.instance.applyCoupon('FREESHIP');
    // Let fire-and-forget persists land before the wipe.
    await Future.delayed(const Duration(milliseconds: 100));

    // Simulate restart: wipe memory, reload from prefs.
    CartStore.resetForTests();
    AddressStore.resetForTests();
    WalletStore.resetForTests();
    WishlistStore.resetForTests();
    PaymentStore.resetForTests();
    await CartStore.instance.load();
    await AddressStore.instance.load();
    await WalletStore.instance.load();
    await WishlistStore.instance.load();
    await PaymentStore.instance.load();

    expect(CartStore.instance.qty(_big.id), 2);
    expect(AddressStore.instance.hasValid, isTrue);
    expect(AddressStore.instance.displayLine,
        contains('Test User'));
    expect(WalletStore.instance.balance, 500);
    expect(WishlistStore.instance.contains(_big.id), isTrue);
    expect(PaymentStore.instance.coupon, 'FREESHIP');
  });

  test('5. Invalid address cannot hijack the default', () {
    AddressStore.instance.save(_addr);
    expect(AddressStore.instance.hasValid, isTrue);

    AddressStore.instance.add(_badAddr);
    // Rejected: default stays on the valid entry.
    expect(AddressStore.instance.select('b2'), isFalse);
    expect(AddressStore.instance.defaultId, 'b1');
    expect(AddressStore.instance.hasValid, isTrue);
    expect(AddressStore.instance.displayLine,
        contains('123 Main Street'));
  });

  test('6. Phone OTP logs in via phone identity (not email)', () async {
    await ProfileStore.instance
        .save(phone: '9876543210', name: 'Ravi');
    expect(ProfileStore.instance.isLoggedIn, isTrue);
    expect(ProfileStore.instance.email, isNull);
    expect(ProfileStore.instance.phone, '9876543210');
  });

  test('7. Applock backoff locks then releases', () async {
    expect(
        await ApplockStore.instance.enable('1357', '1357'),
        isTrue);
    expect(await ApplockStore.instance.verify('0000'), isFalse);
    expect(ApplockStore.instance.locked, isTrue);
    expect(ApplockStore.instance.lockLeft, greaterThan(0));
    // Correct PIN inside the window is still rejected.
    expect(await ApplockStore.instance.verify('1357'), isFalse);
    ApplockStore.clearLockoutForTests();
    expect(await ApplockStore.instance.verify('1357'), isTrue);
  });

  testWidgets('9. Green tick auto-opens tracking, back returns to root',
      (tester) async {
    CartStore.instance.add(_big);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open_checkout_test'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              ),
              child: const Text('Open checkout'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open_checkout_test')));
    await _frames(tester);

    await tester.tap(find.byKey(
        const ValueKey('checkout_place_order')));
    await _frames(tester, 3);
    expect(find.text('Payment Successful!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2100));
    await _frames(tester, 5);
    expect(find.byKey(const ValueKey('track_screen')), findsOneWidget);
    expect(find.text('Order Placed!'), findsNothing);
    expect(
        find.byKey(const ValueKey('payment_success_tick')),
        findsNothing);

    // The app root is kept and the address/checkout/splash routes are
    // gone: back returns to the root, never to the auto-advancing splash.
    final nav =
        tester.state<NavigatorState>(find.byType(Navigator));
    expect(nav.canPop(), isTrue);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _frames(tester);
    expect(find.byKey(const ValueKey('open_checkout_test')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_screen')), findsNothing);
    expect(
        find.byKey(const ValueKey('payment_success_tick')),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(Container());
  });
}
