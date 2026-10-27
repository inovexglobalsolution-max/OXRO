import 'package:flutter/foundation.dart';

import 'package:oxro/features/checkout/data/payment_store.dart';

/// Mock payment gateway seam. The real Razorpay adapter replaces
/// [charge] without changing the checkout flow.
class PaymentGateway {
  PaymentGateway._();

  static final PaymentGateway instance = PaymentGateway._();

  bool _failNext = false;

  @visibleForTesting
  void failNextForTests() => _failNext = true;

  @visibleForTesting
  void resetForTests() => _failNext = false;

  Future<bool> charge(PaymentMethod method, int amountPaise) async {
    if (method == PaymentMethod.cod) return true;
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (_failNext) {
      _failNext = false;
      return false;
    }
    return true;
  }
}
