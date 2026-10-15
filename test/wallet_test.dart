import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wallet/presentation/screens/wallet_screen.dart';

const _p = Product(
  id: 3001,
  name: 'Wallet Tee',
  brand: 'OXRO',
  price: 499,
  mrp: 799,
  rating: 4.3,
  reviews: 120,
  icon: Icons.checkroom,
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

void main() {
  setUp(() {
    WalletStore.resetForTests();
    CartStore.resetForTests();
    PaymentStore.resetForTests();
  });

  test('add/deduct/insufficient', () {
    expect(WalletStore.instance.balance, 0);
    WalletStore.instance.add(500);
    expect(WalletStore.instance.balance, 500);
    expect(WalletStore.instance.txs.length, 1);

    expect(WalletStore.instance.deduct(600), isFalse);
    expect(WalletStore.instance.balance, 500);

    expect(WalletStore.instance.deduct(200), isTrue);
    expect(WalletStore.instance.balance, 300);
    expect(WalletStore.instance.txs.first.amount, -200);
  });

  testWidgets('Wallet screen top-up works', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('wallet_scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet_empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet_add_500')));
    await _settle(tester);
    expect(WalletStore.instance.balance, 500);
    expect(find.byKey(const ValueKey('wallet_empty')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Wallet opens from Account menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.text('Account'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('profile_wallet')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_wallet')),
      find.byKey(const ValueKey('profile_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_wallet')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('wallet_scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout shows wallet method with balance', (tester) async {
    WalletStore.instance.add(1000);
    CartStore.instance.add(_p);
    AddressStore.resetForTests();
    AddressStore.instance.add(const Address(
      id: 'w1',
      label: 'Home',
      name: 'Test User',
      phone: '9876543210',
      line: '123 Main Street',
      city: 'Chennai',
      pin: '600001',
    ));
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('pay_wallet')), findsOneWidget);
    expect(find.textContaining('₹1,000'), findsWidgets);
    expect(tester.takeException(), isNull);
    WalletStore.resetForTests();
    CartStore.resetForTests();
    AddressStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Wallet 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      WalletStore.resetForTests();
      WalletStore.instance.add(500);
      await tester.pumpWidget(
          const MaterialApp(home: WalletScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'wallet at $size');
      await _dispose(tester);
    }
    WalletStore.resetForTests();
  });
}
