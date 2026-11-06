import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';

/// Payment gateway. Real Razorpay checkout for UPI/Card; COD handled by caller.
class PaymentGateway {
  PaymentGateway._();

  static final PaymentGateway instance = PaymentGateway._();

  bool _failNext = false;

  @visibleForTesting
  void failNextForTests() => _failNext = true;

  @visibleForTesting
  void resetForTests() => _failNext = false;

  Future<bool> charge(
    PaymentMethod method,
    int amountPaise, {
    BuildContext? context,
  }) async {
    if (method == PaymentMethod.cod) return true;

    // Test / offline / no-UI path: keep the legacy mock so widget tests stay deterministic.
    if (context == null || !CustomerIdentity.networkEnabled) {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (_failNext) {
        _failNext = false;
        return false;
      }
      return true;
    }

    final client = ApiClient();
    debugPrint('PaymentGateway: baseUrl=${client.baseUrl}');
    try {
      // 1. Create Razorpay order server-side (key_secret never leaves backend).
      final createRes = await client.post(
        '/checkout/razorpay-order',
        body: {
          'amountPaise': amountPaise,
          'receipt': 'oxro_${DateTime.now().millisecondsSinceEpoch}',
        },
        timeout: const Duration(seconds: 30),
      );
      if (createRes.statusCode != 201) {
        debugPrint(
          'PaymentGateway: create order HTTP ${createRes.statusCode} ${createRes.body}',
        );
        return false;
      }
      final created = jsonDecode(createRes.body) as Map<String, dynamic>;
      final keyId = created['keyId'] as String?;
      final razorpayOrderId = created['razorpayOrderId'] as String?;
      if (keyId == null || razorpayOrderId == null) return false;

      // 2. Open Razorpay checkout (GPay/UPI/Cards).
      final completer = Completer<Map<String, dynamic>?>();
      final razorpay = Razorpay();
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
        if (!completer.isCompleted) {
          completer.complete({
            'paymentId': r.paymentId,
            'orderId': r.orderId,
            'signature': r.signature,
          });
        }
      });
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
        if (!completer.isCompleted) completer.complete(null);
      });
      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
        if (!completer.isCompleted) completer.complete(null);
      });

      razorpay.open({
        'key': keyId,
        'amount': amountPaise,
        'currency': 'INR',
        'name': 'OXRO',
        'description': 'Food order payment',
        'order_id': razorpayOrderId,
        'method': {
          'upi': true,
          'card': true,
          'netbanking': true,
          'wallet': true,
        },
      });

      final result = await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () => null,
      );
      razorpay.clear();

      if (result == null) return false;

      // 3. Verify signature server-side.
      final verifyRes = await client.post(
        '/checkout/verify',
        body: {
          'razorpayOrderId': result['orderId'],
          'razorpayPaymentId': result['paymentId'],
          'razorpaySignature': result['signature'],
        },
        timeout: const Duration(seconds: 30),
      );
      return verifyRes.statusCode == 200;
    } catch (e, st) {
      debugPrint('PaymentGateway.charge: $e\n$st');
      return false;
    }
  }
}
