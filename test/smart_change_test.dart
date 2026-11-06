import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/checkout/presentation/screens/payment_method_screen.dart';
import 'package:oxro/features/checkout/presentation/widgets/cod_smart_change_dialog.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/wallet/data/smart_change_credit.dart';
import 'package:oxro/features/wallet/data/wallet_store.dart';
import 'package:oxro/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:oxro/app/repositories/smart_change_repo.dart';

const _p = Product(
  id: 950,
  name: 'Smart Curry',
  brand: 'OXRO',
  restaurantId: 'R-SMART',
  restaurantName: 'Smart Kitchen',
  price: 320,
  mrp: 399,
  rating: 4.4,
  reviews: 30,
  icon: Icons.restaurant,
  colors: [Colors.white],
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

Future<void> _frames(WidgetTester tester, [int n = 5]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Host that opens the Smart Change dialog like the payment screen does.
class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.orderAmountPaise, this.onResult});

  final int orderAmountPaise;
  final void Function(CodSmartChangeResult?)? onResult;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog<CodSmartChangeResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            CodSmartChangeDialog(orderAmountPaise: widget.orderAmountPaise),
      ).then((r) => widget.onResult?.call(r));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('payment')));
  }
}

Future<void> _openDialog(WidgetTester tester, int orderPaise) async {
  await tester.pumpWidget(
    MaterialApp(home: _DialogHost(orderAmountPaise: orderPaise)),
  );
  await _frames(tester, 2);
  expect(find.byKey(const ValueKey('cod_smart_change')), findsOneWidget);
}

void main() {
  setUp(() {
    CartStore.resetForTests();
    AddressStore.resetForTests();
    PaymentStore.resetForTests();
    OrderStore.resetForTests();
    WalletStore.resetForTests();
    NotifStore.resetForTests();
    SmartChangeRepo.activateOverride = null;
    SmartChangeRepo.linkOverride = null;
    SmartChangeRepo.creditsOverride = null;
  });

  tearDown(() {
    SmartChangeRepo.activateOverride = null;
    SmartChangeRepo.linkOverride = null;
    SmartChangeRepo.creditsOverride = null;
  });

  void mockActivate({bool fail = false, bool unreachable = false}) {
    SmartChangeRepo.activateOverride =
        ({
          required int orderAmountPaise,
          required int cashAmountPaise,
          required String customerId,
          required String idempotencyKey,
        }) async {
          if (unreachable) {
            throw Exception('connection refused');
          }
          if (fail) {
            throw const SmartChangeException('Smart Change activation failed');
          }
          return SmartChangeActivation(
            txnId: 'SC-TEST01',
            orderAmountPaise: orderAmountPaise,
            cashAmountPaise: cashAmountPaise,
            remainingChangePaise: cashAmountPaise - orderAmountPaise,
          );
        };
  }

  Future<void> openPaymentScreen(WidgetTester tester) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(const MaterialApp(home: PaymentMethodScreen()));
    await _frames(tester);
    await tester.scrollUntilVisible(
      find.text('Cash on Delivery'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await _frames(tester, 2);
  }

  // 1. COD selected → Smart Change popup appears.
  testWidgets('COD tap shows the Smart Change consent popup', (tester) async {
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);

    expect(find.byKey(const ValueKey('cod_smart_change')), findsOneWidget);
    expect(find.text('💰 OXRO Smart Change'), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_agree')), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_cancel')), findsOneWidget);
    expect(
      find.textContaining('No physical change will be returned'),
      findsOneWidget,
    );
    expect(PaymentStore.instance.method, PaymentMethod.upi);
  });

  // 3. Customer declines → COD checkout is stopped.
  testWidgets('Declining Smart Change stops COD selection', (tester) async {
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);

    await tester.tap(find.byKey(const ValueKey('sc_cancel')));
    await _frames(tester, 2);

    expect(find.byKey(const ValueKey('cod_smart_change')), findsNothing);
    expect(PaymentStore.instance.method, PaymentMethod.upi);
    expect(PaymentStore.instance.hasCodSmartChange, isFalse);
    // Still on the payment selection screen.
    expect(find.byKey(const ValueKey('checkout_pay_using_row')), findsNothing);
    expect(find.text('Select Payment Method'), findsOneWidget);
  });

  // 2. Customer accepts → cash amount entry screen opens.
  testWidgets('Accepting the consent opens the cash amount entry', (
    tester,
  ) async {
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);

    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    expect(find.byKey(const ValueKey('cod_cash_input')), findsOneWidget);
    expect(find.text('Order Amount'), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_continue')), findsOneWidget);
  });

  // 4. ₹320 order + ₹500 cash → ₹180 wallet credit.
  testWidgets('₹320 order + ₹500 cash shows ₹180 wallet credit', (
    tester,
  ) async {
    mockActivate();
    CodSmartChangeResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _DialogHost(orderAmountPaise: 32000, onResult: (r) => result = r),
      ),
    );
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();

    expect(find.text('₹320'), findsWidgets); // order amount
    expect(find.text('₹500'), findsWidgets); // cash amount
    expect(find.text('₹180'), findsNWidgets(2)); // change + wallet credit

    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);
    expect(find.text('YES, ADD TO WALLET'), findsOneWidget);
    expect(
      find.textContaining('will be credited to your OXRO Money Wallet'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('sc_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('sc_success_tick')), findsOneWidget);
    expect(
      find.text('OXRO Smart Change Activated Successfully!'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await _frames(tester, 2);
    expect(result, isNotNull);
    expect(result!.confirmed, isTrue);
    expect(result!.txnId, 'SC-TEST01');
    expect(result!.cashAmountPaise, 50000);
    expect(result!.walletCreditPaise, 18000);
  });

  // 5. Exact cash payment → ₹0 wallet credit.
  testWidgets('Exact cash shows ₹0 wallet credit and still activates', (
    tester,
  ) async {
    mockActivate();
    CodSmartChangeResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _DialogHost(orderAmountPaise: 32000, onResult: (r) => result = r),
      ),
    );
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '320');
    await tester.pump();

    expect(find.text('₹0'), findsNWidgets(2)); // change + credit are zero
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sc_continue')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await _frames(tester, 2);
    expect(result!.confirmed, isTrue);
    expect(result!.walletCreditPaise, 0);
  });

  // 6. Invalid cash amount → validation error, no confirmation.
  testWidgets('Invalid cash amount shows an error and blocks continue', (
    tester,
  ) async {
    mockActivate();
    await _openDialog(tester, 32000);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '100');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('cod_change_insufficient')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sc_continue')))
          .onPressed,
      isNull,
    );

    // Negative / garbage input is also rejected.
    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '-5');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('sc_continue')))
          .onPressed,
      isNull,
    );
  });

  // 8. Failed backend confirmation → error, no success tick, no COD.
  testWidgets('Activation failure shows an error instead of success', (
    tester,
  ) async {
    mockActivate(fail: true);
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);

    await tester.tap(find.byKey(const ValueKey('sc_confirm')));
    await tester.pump();
    await _frames(tester, 2);

    expect(find.byKey(const ValueKey('sc_error')), findsOneWidget);
    expect(find.byKey(const ValueKey('sc_success_tick')), findsNothing);
    // COD is NOT selected without server confirmation.
    expect(PaymentStore.instance.method, PaymentMethod.upi);
    expect(PaymentStore.instance.hasCodSmartChange, isFalse);
  });

  // Transport failure (server unreachable) shows the retry message.
  testWidgets('Unreachable backend shows the retry error message', (
    tester,
  ) async {
    mockActivate(unreachable: true);
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);

    await tester.tap(find.byKey(const ValueKey('sc_confirm')));
    await tester.pump();
    await _frames(tester, 2);

    expect(find.byKey(const ValueKey('sc_error')), findsOneWidget);
    expect(
      find.text('Could not reach OXRO Smart Change. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sc_success_tick')), findsNothing);
    expect(PaymentStore.instance.method, PaymentMethod.upi);
  });

  // Full accept → confirm flow selects COD with the saved consent.
  testWidgets('Accept + confirm selects COD and stores the consent', (
    tester,
  ) async {
    mockActivate();
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await _frames(tester, 3);

    expect(PaymentStore.instance.method, PaymentMethod.cod);
    expect(PaymentStore.instance.hasCodSmartChange, isTrue);
    expect(PaymentStore.instance.codTxnId, 'SC-TEST01');
    // Credit is computed from the live quote (cash 500 − order total).
    expect(
      PaymentStore.instance.codWalletCreditPaise,
      50000 - PaymentStore.instance.codConsentAmountPaise,
    );
    expect(PaymentStore.instance.codChangePreference, 'wallet');
  });

  // 9 (client). Duplicate requests → no duplicate popup / consent.
  testWidgets('Re-tapping COD after consent skips the popup', (tester) async {
    mockActivate();
    await openPaymentScreen(tester);
    await tester.tap(find.text('Cash on Delivery'));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await _frames(tester, 3);

    // Consent valid for the current quote → direct selection, no popup.
    // (The subtitle finder targets the COD row — the Recommended section
    // also lists the previously selected label after activation.)
    await tester.tap(find.text('Pay with cash at delivery'));
    await _frames(tester, 2);
    expect(find.byKey(const ValueKey('cod_smart_change')), findsNothing);
    expect(PaymentStore.instance.method, PaymentMethod.cod);
    expect(PaymentStore.instance.codTxnId, 'SC-TEST01');
  });

  // COD order links the consent to the order id before proceeding.
  testWidgets('COD place order links Smart Change to the order id', (
    tester,
  ) async {
    String? linkedTxn;
    String? linkedOrder;
    SmartChangeRepo.linkOverride = (txnId, orderId) async {
      linkedTxn = txnId;
      linkedOrder = orderId;
    };
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);
    PaymentStore.instance.setCodSmartChange(
      txnId: 'SC-LINK01',
      cashAmount: 500,
      walletCreditPaise: 18000,
      consentAmountPaise: PaymentStore.instance.toPayPaise,
    );

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    final ordersBefore = OrderStore.instance.all.length;
    await tester.tap(find.byKey(const ValueKey('checkout_place_order')));
    await _frames(tester, 4);

    expect(linkedTxn, 'SC-LINK01');
    expect(linkedOrder, isNotNull);
    expect(linkedOrder!, startsWith('OXRO'));
    expect(OrderStore.instance.all.length, ordersBefore + 1);
    expect(OrderStore.instance.all.first.id, linkedOrder);
    expect(find.byKey(const ValueKey('payment_success_tick')), findsOneWidget);
    // Consent cleared after the order.
    expect(PaymentStore.instance.hasCodSmartChange, isFalse);
    expect(CartStore.instance.count, 0);
  });

  // Link failure → the COD order must NOT be placed.
  testWidgets('Link failure aborts the COD order', (tester) async {
    SmartChangeRepo.linkOverride = (txnId, orderId) async {
      throw const SmartChangeException('Transaction already linked');
    };
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    PaymentStore.instance.select(PaymentMethod.cod);
    PaymentStore.instance.setCodSmartChange(
      txnId: 'SC-LINK02',
      cashAmount: 500,
      walletCreditPaise: 18000,
      consentAmountPaise: PaymentStore.instance.toPayPaise,
    );

    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    final ordersBefore = OrderStore.instance.all.length;
    await tester.tap(find.byKey(const ValueKey('checkout_place_order')));
    await _frames(tester, 4);

    expect(find.byKey(const ValueKey('smart_change_failed')), findsOneWidget);
    expect(OrderStore.instance.all.length, ordersBefore);
    expect(find.byKey(const ValueKey('payment_success_tick')), findsNothing);
    // Cart kept — order did not proceed.
    expect(CartStore.instance.count, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('smart_change_failed_ok')));
    await _frames(tester, 2);
  });

  // 7 (client side). Credited transaction → wallet credit + notification.
  testWidgets('Credited Smart Change is applied to the wallet once', (
    tester,
  ) async {
    SmartChangeRepo.creditsOverride = (customerId) async => [
      const SmartChangeCredit(
        txnId: 'SC-WAL01',
        orderId: 'OXRO777',
        walletCreditPaise: 18065,
        walletTransactionId: 'WTX01',
      ),
    ];

    await tester.pumpWidget(const MaterialApp(home: WalletScreen()));
    await _frames(tester, 4);

    expect(WalletStore.instance.balancePaise, 18065);
    expect(WalletStore.instance.txs.length, 1);
    expect(WalletStore.instance.txs.first.id, 'SC-WAL01');
    expect(WalletStore.instance.txs.first.amountPaise, 18065);

    final notif = NotifStore.instance.items.first;
    expect(notif.id, 'sc_SC-WAL01');
    expect(
      notif.sub,
      contains('₹180.65 has been successfully credited to your OXRO Wallet'),
    );

    // Applying the same credit again is a no-op (duplicate guard).
    expect(WalletStore.instance.addPaise(18065, txnId: 'SC-WAL01'), isFalse);
    expect(WalletStore.instance.balancePaise, 18065);
    expect(WalletStore.instance.txs.length, 1);
  });

  // Shared applier (startup + wallet): applies once, safe to re-run,
  // dedupes across customer ids (guest ↔ logged-in).
  test(
    'SmartChangeWalletCredit.apply credits once and is idempotent',
    () async {
      SmartChangeRepo.creditsOverride = (customerId) async => [
        const SmartChangeCredit(
          txnId: 'SC-APPLY1',
          orderId: 'OXRO4242',
          walletCreditPaise: 8000,
          walletTransactionId: 'WTX9',
        ),
      ];

      final first = await SmartChangeWalletCredit.apply();
      expect(first.ok, isTrue);
      expect(first.appliedCount, 1);
      expect(WalletStore.instance.balancePaise, 8000);

      final second = await SmartChangeWalletCredit.apply();
      expect(second.appliedCount, 0);
      expect(WalletStore.instance.balancePaise, 8000);
      expect(WalletStore.instance.txs.length, 1);
      expect(
        NotifStore.instance.items.where((n) => n.id == 'sc_SC-APPLY1').length,
        1,
      );
    },
  );

  // Wallet unit: exact paise math + duplicate protection.
  test('addPaise credits exact paise once; deductPaise debits exactly', () {
    expect(WalletStore.instance.addPaise(18065, txnId: 'SCU1'), isTrue);
    expect(WalletStore.instance.balancePaise, 18065);
    expect(WalletStore.instance.balance, 180); // legacy rupee getter
    expect(WalletStore.instance.addPaise(18065, txnId: 'SCU1'), isFalse);
    expect(WalletStore.instance.balancePaise, 18065);

    // Exact bill debit — no rupee rounding.
    expect(WalletStore.instance.deductPaise(11110), isTrue);
    expect(WalletStore.instance.balancePaise, 6955);
    expect(WalletStore.instance.deductPaise(999999), isFalse);
    expect(WalletStore.instance.balancePaise, 6955);
  });

  // Duplicate notification ids are never shown twice.
  test('NotifStore.add deduplicates by id', () {
    final added = NotifStore.instance.add(
      id: 'sc_dup',
      title: 'Smart Change credit',
      sub: '₹180 credited',
    );
    expect(added, isTrue);
    final again = NotifStore.instance.add(
      id: 'sc_dup',
      title: 'Smart Change credit',
      sub: '₹180 credited',
    );
    expect(again, isFalse);
    expect(NotifStore.instance.items.where((n) => n.id == 'sc_dup').length, 1);
  });

  // Spec: ₹420 order + ₹500 cash → remaining change ₹80.
  testWidgets('₹420 order + ₹500 cash shows ₹80 remaining change', (
    tester,
  ) async {
    mockActivate();
    await _openDialog(tester, 42000);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();

    expect(find.text('₹420'), findsWidgets);
    expect(find.text('₹500'), findsWidgets);
    expect(find.text('₹80'), findsNWidgets(2)); // change + wallet credit
  });

  // Spec: cash == order amount → Exact Cash display, no wallet credit.
  testWidgets('Exact cash displays the Exact Cash badge', (tester) async {
    mockActivate();
    await _openDialog(tester, 42000);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '420');
    await tester.pump();

    expect(find.byKey(const ValueKey('cod_exact_cash')), findsOneWidget);
    expect(find.text('Exact Cash — no wallet credit needed.'), findsOneWidget);
    expect(find.byKey(const ValueKey('cod_change_insufficient')), findsNothing);
  });

  // Spec: cash below order amount → Insufficient Cash display.
  testWidgets('₹300 cash for a ₹420 order shows Insufficient Cash', (
    tester,
  ) async {
    mockActivate();
    await _openDialog(tester, 42000);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);

    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '300');
    await tester.pump();

    expect(
      find.byKey(const ValueKey('cod_change_insufficient')),
      findsOneWidget,
    );
    expect(find.textContaining('Insufficient Cash'), findsOneWidget);
    expect(find.byKey(const ValueKey('cod_exact_cash')), findsNothing);
  });

  // Spec: NO, CANCEL ORDER at the confirmation step stops COD.
  testWidgets('Rejecting at confirmation keeps COD unselected', (tester) async {
    mockActivate();
    CodSmartChangeResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _DialogHost(orderAmountPaise: 42000, onResult: (r) => result = r),
      ),
    );
    await _frames(tester, 2);
    await tester.tap(find.byKey(const ValueKey('sc_agree')));
    await _frames(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('cod_cash_input')), '500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sc_continue')));
    await _frames(tester, 2);

    await tester.tap(find.byKey(const ValueKey('sc_confirm_cancel')));
    await _frames(tester, 2);

    expect(find.byKey(const ValueKey('cod_smart_change')), findsNothing);
    expect(result, isNotNull);
    expect(result!.confirmed, isFalse);
    expect(PaymentStore.instance.hasCodSmartChange, isFalse);
  });
}
