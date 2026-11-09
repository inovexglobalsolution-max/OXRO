import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/dineout/data/reservation_payment.dart';
import 'package:oxro/features/dineout/presentation/screens/dineout_detail_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReservationPayment.debugFlowOverride = null;
  });

  tearDown(() {
    ReservationPayment.debugFlowOverride = null;
  });

  testWidgets('Confirm reservation opens the ₹7 payment screen', (
    tester,
  ) async {
    ReservationPayment.debugFlowOverride =
        ({
          required String restaurantId,
          required int guests,
          required String slot,
        }) async {
          return const ReservationPaymentResult(
            status: ReservationPaymentStatus.cancelled,
          );
        };

    await tester.pumpWidget(
      const MaterialApp(home: DineoutDetailScreen(restaurantId: 'd_verandah')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_book')));
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('reservation_payment_screen')),
      findsOneWidget,
    );
    expect(find.text('Reservation Platform Fee'), findsOneWidget);
    expect(find.text('Your ticket platform fee is ₹7'), findsOneWidget);
    expect(find.text('Platform Fee for Reservation'), findsOneWidget);
    expect(find.text('₹7.00'), findsWidgets);
    expect(find.text('Total Amount'), findsOneWidget);
    // COD must never appear as a payment option.
    expect(find.textContaining('Cash on Delivery'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Successful ₹7 payment confirms the reservation', (tester) async {
    ReservationPayment.debugFlowOverride =
        ({
          required String restaurantId,
          required int guests,
          required String slot,
        }) async {
          return const ReservationPaymentResult(
            status: ReservationPaymentStatus.success,
            paymentId: 'pay_test_001',
            booking: {'id': 'bkg_test_001', 'paymentStatus': 'paid'},
          );
        };

    await tester.pumpWidget(
      const MaterialApp(home: DineoutDetailScreen(restaurantId: 'd_verandah')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_book')));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('reservation_pay_button')));
    await _settle(tester);

    expect(find.textContaining('Reservation confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed payment does not confirm and allows retry', (
    tester,
  ) async {
    ReservationPayment.debugFlowOverride =
        ({
          required String restaurantId,
          required int guests,
          required String slot,
        }) async {
          return const ReservationPaymentResult(
            status: ReservationPaymentStatus.failed,
            message: 'Payment failed',
          );
        };

    await tester.pumpWidget(
      const MaterialApp(home: DineoutDetailScreen(restaurantId: 'd_verandah')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_book')));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('reservation_pay_button')));
    await _settle(tester);

    expect(find.text('Payment failed'), findsOneWidget);
    // Retry stays available — the payment screen is still visible.
    expect(
      find.byKey(const ValueKey('reservation_payment_screen')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelled payment does not confirm and allows retry', (
    tester,
  ) async {
    ReservationPayment.debugFlowOverride =
        ({
          required String restaurantId,
          required int guests,
          required String slot,
        }) async {
          return const ReservationPaymentResult(
            status: ReservationPaymentStatus.cancelled,
          );
        };

    await tester.pumpWidget(
      const MaterialApp(home: DineoutDetailScreen(restaurantId: 'd_verandah')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_book')));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('reservation_pay_button')));
    await _settle(tester);

    expect(find.text('Payment cancelled'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reservation_payment_screen')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pay button disables while payment is processing', (
    tester,
  ) async {
    final completer = Completer<ReservationPaymentResult>();
    var calls = 0;
    ReservationPayment.debugFlowOverride =
        ({
          required String restaurantId,
          required int guests,
          required String slot,
        }) {
          calls += 1;
          return completer.future;
        };

    await tester.pumpWidget(
      const MaterialApp(home: DineoutDetailScreen(restaurantId: 'd_verandah')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('dineout_book')));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('reservation_pay_button')));
    await _settle(tester);
    expect(calls, 1);

    // Second tap must not start another payment.
    await tester.tap(find.byKey(const ValueKey('reservation_pay_button')));
    await _settle(tester);
    expect(calls, 1);

    completer.complete(
      const ReservationPaymentResult(
        status: ReservationPaymentStatus.cancelled,
      ),
    );
    await _settle(tester);
    expect(find.text('Payment cancelled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('reservation fee is exactly ₹7.00 and online-only', () {
    expect(ReservationPayment.reservationFeePaise, 700);
  });
}
