import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/repositories/smart_change_repo.dart';
import 'package:oxro/features/rider/presentation/screens/rider_cod_collect_screen.dart';
import 'package:oxro/features/rider/presentation/screens/rider_offers_screen.dart';

void main() {
  setUp(() {
    SmartChangeRepo.collectOverride = null;
    SmartChangeRepo.getOverride = null;
    SmartChangeRepo.collectableOverride = null;
  });

  tearDown(() {
    SmartChangeRepo.collectOverride = null;
    SmartChangeRepo.getOverride = null;
    SmartChangeRepo.collectableOverride = null;
  });

  Future<void> frames(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  const txn = SmartChangeActivation(
    txnId: 'SC-RIDER01',
    orderId: 'OXRO555',
    orderAmountPaise: 42000,
    cashAmountPaise: 50000,
    remainingChangePaise: 8000,
  );

  // Delivery partner entry point from the Rider Hub.
  testWidgets('Rider Hub shows the Smart Change COD entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RiderOffersScreen()));
    await frames(tester);
    expect(find.byKey(const ValueKey('rider_smart_change')), findsOneWidget);
    expect(find.text('Smart Change COD collections'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Spec 5: partner opens the order → order amount, declared cash,
  // expected change are displayed.
  testWidgets('Collection detail shows amounts and Confirm button', (
    tester,
  ) async {
    SmartChangeRepo.getOverride = (txnId) async => txn;

    await tester.pumpWidget(
      const MaterialApp(home: RiderCodCollectScreen(txnId: 'SC-RIDER01')),
    );
    await frames(tester);

    expect(find.byKey(const ValueKey('rider_sc_detail')), findsOneWidget);
    expect(find.text('Order OXRO555'), findsOneWidget);
    expect(find.text('Order Amount'), findsOneWidget);
    expect(find.text('₹420'), findsOneWidget);
    expect(find.text('Customer Declared Cash'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);
    expect(find.text('Expected Change'), findsOneWidget);
    expect(find.text('₹80'), findsOneWidget);
    expect(find.byKey(const ValueKey('rider_sc_confirm')), findsOneWidget);
    expect(find.text('Confirm Cash Collected'), findsOneWidget);
  });

  // Spec 5 + 7: confirm cash → backend verification → wallet credit
  // message shown exactly once.
  testWidgets('Confirm Cash Collected processes the wallet credit', (
    tester,
  ) async {
    var calls = 0;
    SmartChangeRepo.getOverride = (txnId) async => txn;
    SmartChangeRepo.collectOverride =
        ({required txnId, required actualCashPaise, required partnerId}) async {
          calls++;
          expect(txnId, 'SC-RIDER01');
          expect(actualCashPaise, 50000);
          return txn;
        };

    await tester.pumpWidget(
      const MaterialApp(home: RiderCodCollectScreen(txnId: 'SC-RIDER01')),
    );
    await frames(tester);

    await tester.tap(find.byKey(const ValueKey('rider_sc_confirm')));
    await frames(tester);

    expect(calls, 1);
    expect(find.byKey(const ValueKey('rider_sc_success')), findsOneWidget);
    expect(
      find.textContaining('credited to the customer\'s OXRO Money Wallet'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('rider_sc_error')), findsNothing);
    // Button disabled after success — repeated taps cannot double-collect.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('rider_sc_confirm')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('rider_sc_confirm')));
    await frames(tester);
    expect(calls, 1);
  });

  // Spec 5: wallet credit failure → return physical change instruction.
  testWidgets('Credit failure instructs the partner to return change', (
    tester,
  ) async {
    SmartChangeRepo.getOverride = (txnId) async => txn;
    SmartChangeRepo.collectOverride =
        ({required txnId, required actualCashPaise, required partnerId}) async {
          throw const SmartChangeException(
            'Wallet credit failed — transaction pending reconciliation',
          );
        };

    await tester.pumpWidget(
      const MaterialApp(home: RiderCodCollectScreen(txnId: 'SC-RIDER01')),
    );
    await frames(tester);

    await tester.tap(find.byKey(const ValueKey('rider_sc_confirm')));
    await frames(tester);

    expect(find.byKey(const ValueKey('rider_sc_error')), findsOneWidget);
    expect(find.textContaining('Return the physical change'), findsOneWidget);
    expect(find.byKey(const ValueKey('rider_sc_success')), findsNothing);
    // Retry stays possible (collect is idempotent server-side).
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('rider_sc_confirm')))
          .onPressed,
      isNotNull,
    );
  });

  // List mode: collectable orders from the backend.
  testWidgets('List mode shows collectable Smart Change orders', (
    tester,
  ) async {
    SmartChangeRepo.collectableOverride = () async => const [txn];

    await tester.pumpWidget(const MaterialApp(home: RiderCodCollectScreen()));
    await frames(tester);

    expect(find.byKey(const ValueKey('rider_sc_list')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('rider_sc_card_SC-RIDER01')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('rider_sc_open_SC-RIDER01')),
      findsOneWidget,
    );
    expect(find.text('₹80'), findsOneWidget);
  });

  // Backend verification failure — error surfaced, no fake success.
  testWidgets('Backend verification failure shows an error', (tester) async {
    SmartChangeRepo.getOverride = (txnId) async => txn;
    SmartChangeRepo.collectOverride =
        ({required txnId, required actualCashPaise, required partnerId}) async {
          throw const SmartChangeException(
            'Actual cash received must be >= order amount',
          );
        };

    await tester.pumpWidget(
      const MaterialApp(home: RiderCodCollectScreen(txnId: 'SC-RIDER01')),
    );
    await frames(tester);

    await tester.tap(find.byKey(const ValueKey('rider_sc_confirm')));
    await frames(tester);

    expect(find.byKey(const ValueKey('rider_sc_error')), findsOneWidget);
    expect(find.textContaining('must be >= order amount'), findsOneWidget);
    expect(find.byKey(const ValueKey('rider_sc_success')), findsNothing);
  });

  // Client-side guard: cash below the order amount never reaches the API.
  testWidgets('Cash below order amount disables Confirm', (tester) async {
    var calls = 0;
    SmartChangeRepo.getOverride = (txnId) async => txn;
    SmartChangeRepo.collectOverride =
        ({required txnId, required actualCashPaise, required partnerId}) async {
          calls++;
          return txn;
        };

    await tester.pumpWidget(
      const MaterialApp(home: RiderCodCollectScreen(txnId: 'SC-RIDER01')),
    );
    await frames(tester);

    await tester.enterText(
      find.byKey(const ValueKey('rider_sc_cash_input')),
      '300',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('rider_sc_confirm')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('rider_sc_confirm')));
    await frames(tester);
    expect(calls, 0);
    expect(find.byKey(const ValueKey('rider_sc_error')), findsNothing);
  });
}
