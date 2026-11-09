import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wallet/data/wallet_topup.dart';
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

/// Pumps the wallet screen and dismisses the one-time note dialog.
Future<void> _openWallet(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
  await _settle(tester);
  if (find.text('OXRO Money Note').evaluate().isNotEmpty) {
    await tester.tap(find.text('Agree'));
    await _settle(tester);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WalletStore.resetForTests();
    CartStore.resetForTests();
    PaymentStore.resetForTests();
    WalletTopUp.debugFlowOverride = null;
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

  testWidgets('Wallet top-up never credits fake money offline', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('wallet_scroll')), findsOneWidget);
    expect(find.text('OXRO Money'), findsOneWidget);
    expect(find.text('OXRO Balance'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet_empty')), findsOneWidget);

    // Dismiss the one-time "OXRO Money Note" dialog before interacting.
    expect(find.text('OXRO Money Note'), findsOneWidget);
    await tester.tap(find.text('Agree'));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('wallet_add_500')));
    await _settle(tester);
    // Offline / test path: real Razorpay flow is gated on network — never credit fake money.
    expect(WalletStore.instance.balance, 0);
    expect(find.byKey(const ValueKey('wallet_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Wallet opens from Account menu', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('profile_wallet')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_wallet')),
      find.byKey(const ValueKey('profile_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    expect(find.text('OXRO Money'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile_wallet')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('wallet_scroll')), findsOneWidget);
    expect(find.text('OXRO Money'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Checkout shows wallet method with balance', (tester) async {
    WalletStore.instance.add(1000);
    CartStore.instance.add(_p);
    AddressStore.resetForTests();
    AddressStore.instance.add(
      const Address(
        id: 'w1',
        label: 'Home',
        name: 'Test User',
        phone: '9876543210',
        line: '123 Main Street',
        city: 'Chennai',
        pin: '600001',
      ),
    );
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
      await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'wallet at $size');
      await _dispose(tester);
    }
    WalletStore.resetForTests();
  });

  test('top-up amount bounds are ₹10–₹50,000', () {
    expect(WalletTopUp.validationError(0), isNotNull);
    expect(WalletTopUp.validationError(9), isNotNull);
    expect(WalletTopUp.validationError(10), isNull);
    expect(WalletTopUp.validationError(50000), isNull);
    expect(WalletTopUp.validationError(50001), isNotNull);
    expect(WalletTopUp.validationError(999999), isNotNull);
  });

  testWidgets('Custom amount below minimum shows validation error', (
    tester,
  ) async {
    await _openWallet(tester);
    await tester.enterText(find.byKey(const ValueKey('wallet_amount')), '5');
    await tester.tap(find.byKey(const ValueKey('wallet_add_custom')));
    await _settle(tester);
    expect(find.text('Minimum top-up is ₹10'), findsOneWidget);
    expect(WalletStore.instance.balance, 0);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Custom amount above maximum shows validation error', (
    tester,
  ) async {
    await _openWallet(tester);
    await tester.enterText(
      find.byKey(const ValueKey('wallet_amount')),
      '999999',
    );
    await tester.tap(find.byKey(const ValueKey('wallet_add_custom')));
    await _settle(tester);
    expect(find.text('Maximum top-up is ₹50,000'), findsOneWidget);
    expect(WalletStore.instance.balance, 0);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  for (final amount in [100, 200, 500]) {
    testWidgets('₹$amount preset top-up credits after verification', (
      tester,
    ) async {
      WalletTopUp.debugFlowOverride = (amountPaise) async {
        expect(amountPaise, amount * 100);
        return WalletTopUpResult(
          status: WalletTopUpStatus.success,
          paymentId: 'pay_$amount',
          creditedPaise: amountPaise,
          balancePaise: amountPaise,
        );
      };
      await _openWallet(tester);
      await tester.tap(find.byKey(ValueKey('wallet_add_$amount')));
      await _settle(tester);
      expect(WalletStore.instance.balancePaise, amount * 100);
      expect(find.byKey(ValueKey('wallet_tx_pay_$amount')), findsOneWidget);
      expect(find.text('Payment Successful'), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet_empty')), findsNothing);
      expect(
        find.textContaining('₹${amount.toStringAsFixed(0)}'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await _dispose(tester);
    });
  }

  testWidgets('Custom amount top-up credits exact paise', (tester) async {
    WalletTopUp.debugFlowOverride = (amountPaise) async {
      expect(amountPaise, 77700);
      return WalletTopUpResult(
        status: WalletTopUpStatus.success,
        paymentId: 'pay_custom',
        creditedPaise: amountPaise,
        balancePaise: amountPaise,
      );
    };
    await _openWallet(tester);
    await tester.enterText(find.byKey(const ValueKey('wallet_amount')), '777');
    await tester.tap(find.byKey(const ValueKey('wallet_add_custom')));
    await _settle(tester);
    expect(WalletStore.instance.balancePaise, 77700);
    expect(find.byKey(const ValueKey('wallet_tx_pay_custom')), findsOneWidget);
    expect(find.text('Payment Successful'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Payment cancellation never credits the wallet', (tester) async {
    WalletTopUp.debugFlowOverride = (amountPaise) async {
      return const WalletTopUpResult(status: WalletTopUpStatus.cancelled);
    };
    await _openWallet(tester);
    await tester.tap(find.byKey(const ValueKey('wallet_add_500')));
    await _settle(tester);
    expect(WalletStore.instance.balance, 0);
    expect(find.byKey(const ValueKey('wallet_empty')), findsOneWidget);
    expect(find.text('Payment cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Payment failure shows the message and credits nothing', (
    tester,
  ) async {
    WalletTopUp.debugFlowOverride = (amountPaise) async {
      return const WalletTopUpResult(
        status: WalletTopUpStatus.failed,
        message: 'Payment failed',
      );
    };
    await _openWallet(tester);
    await tester.tap(find.byKey(const ValueKey('wallet_add_200')));
    await _settle(tester);
    expect(WalletStore.instance.balance, 0);
    expect(find.byKey(const ValueKey('wallet_empty')), findsOneWidget);
    expect(find.text('Payment failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Pending payment is not credited', (tester) async {
    WalletTopUp.debugFlowOverride = (amountPaise) async {
      return const WalletTopUpResult(status: WalletTopUpStatus.pending);
    };
    await _openWallet(tester);
    await tester.tap(find.byKey(const ValueKey('wallet_add_100')));
    await _settle(tester);
    expect(WalletStore.instance.balance, 0);
    expect(find.text('Payment is being confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Server error message is surfaced, no credit', (tester) async {
    WalletTopUp.debugFlowOverride = (amountPaise) async {
      return const WalletTopUpResult(
        status: WalletTopUpStatus.error,
        message: 'Could not start payment',
      );
    };
    await _openWallet(tester);
    await tester.tap(find.byKey(const ValueKey('wallet_add_100')));
    await _settle(tester);
    expect(WalletStore.instance.balance, 0);
    expect(find.text('Could not start payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Add button is disabled while a payment is processing', (
    tester,
  ) async {
    final completer = Completer<WalletTopUpResult>();
    var calls = 0;
    WalletTopUp.debugFlowOverride = (amountPaise) {
      calls += 1;
      return completer.future;
    };
    await _openWallet(tester);

    await tester.tap(find.byKey(const ValueKey('wallet_add_100')));
    await _settle(tester);
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Repeated taps while in flight are ignored.
    await tester.tap(find.byKey(const ValueKey('wallet_add_200')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('wallet_add_500')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('wallet_add_custom')));
    await _settle(tester);
    expect(calls, 1);
    expect(WalletStore.instance.balance, 0);

    completer.complete(
      const WalletTopUpResult(status: WalletTopUpStatus.cancelled),
    );
    await _settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Payment cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Duplicate callback never double-credits', (tester) async {
    var calls = 0;
    WalletTopUp.debugFlowOverride = (amountPaise) async {
      calls += 1;
      return WalletTopUpResult(
        status: WalletTopUpStatus.success,
        paymentId: 'pay_dup',
        creditedPaise: amountPaise,
        balancePaise: amountPaise,
        duplicate: calls > 1,
      );
    };
    await _openWallet(tester);

    await tester.tap(find.byKey(const ValueKey('wallet_add_100')));
    await _settle(tester);
    expect(WalletStore.instance.balancePaise, 10000);
    expect(WalletStore.instance.txs.length, 1);

    await tester.tap(find.byKey(const ValueKey('wallet_add_100')));
    await _settle(tester);
    expect(calls, 2);
    expect(WalletStore.instance.balancePaise, 10000);
    expect(WalletStore.instance.txs.length, 1);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
