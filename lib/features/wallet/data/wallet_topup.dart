import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:oxro_pricing/oxro_pricing.dart';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Outcome of a wallet top-up attempt.
enum WalletTopUpStatus { success, cancelled, failed, pending, error, offline }

@immutable
class WalletTopUpResult {
  const WalletTopUpResult({
    required this.status,
    this.message,
    this.paymentId,
    this.creditedPaise,
    this.balancePaise,
    this.duplicate = false,
  });

  final WalletTopUpStatus status;

  /// User-facing message for [WalletTopUpStatus.error] / [WalletTopUpStatus.failed].
  final String? message;
  final String? paymentId;

  /// Exact paise credited by the server (from the verified transaction).
  final int? creditedPaise;

  /// Server-authoritative balance after the credit.
  final int? balancePaise;

  /// True when the backend recognised a replayed callback and skipped the
  /// second credit.
  final bool duplicate;
}

/// Razorpay wallet top-up flow: create order on the backend → open the
/// official Razorpay Checkout (UPI / GPay / cards) → verify the signature
/// server-side. The wallet balance only moves after backend verification.
class WalletTopUp {
  WalletTopUp._();

  /// Bounds enforced here and on the backend (₹10–₹50,000).
  static const int minRupees = 10;
  static const int maxRupees = 50000;

  /// User-facing error when [rupees] is outside the allowed range.
  static String? validationError(int rupees) {
    if (rupees < minRupees) return 'Minimum top-up is ₹$minRupees';
    if (rupees > maxRupees) {
      return 'Maximum top-up is ${Money.inr(maxRupees * Money.paisePerRupee)}';
    }
    return null;
  }

  /// Test seam — replaces the whole network + checkout flow so widget tests
  /// can drive success / cancellation / failure deterministically offline.
  @visibleForTesting
  static Future<WalletTopUpResult> Function(int amountPaise)? debugFlowOverride;

  /// True when a top-up can actually be attempted: real runs need the
  /// network, widget tests run offline unless [debugFlowOverride] is set.
  static bool get canAttemptPayment =>
      debugFlowOverride != null || CustomerIdentity.networkEnabled;

  static Future<WalletTopUpResult> run(int rupees) async {
    final validationError = WalletTopUp.validationError(rupees);
    if (validationError != null) {
      return WalletTopUpResult(
        status: WalletTopUpStatus.error,
        message: validationError,
      );
    }
    final override = debugFlowOverride;
    if (override != null) return override(rupees * 100);
    if (!CustomerIdentity.networkEnabled) {
      return const WalletTopUpResult(status: WalletTopUpStatus.offline);
    }

    final amountPaise = rupees * 100;
    final client = ApiClient();
    final customerId = CustomerIdentity.customerId;
    try {
      // 1. Create the Razorpay order server-side (key secret stays there).
      final createRes = await client.post(
        '/wallet/create-order',
        body: {'amountPaise': amountPaise, 'customerId': customerId},
        timeout: const Duration(seconds: 30),
      );
      if (createRes.statusCode != 201) {
        return WalletTopUpResult(
          status: WalletTopUpStatus.error,
          message: _serverError(createRes.body, 'Could not start payment'),
        );
      }
      final created = jsonDecode(createRes.body) as Map<String, dynamic>;
      final keyId = created['keyId'] as String?;
      final orderId = created['razorpayOrderId'] as String?;
      if (keyId == null || orderId == null) {
        return const WalletTopUpResult(
          status: WalletTopUpStatus.error,
          message: 'Could not start payment',
        );
      }

      // 2. Official Razorpay Checkout — UPI (incl. GPay), cards, netbanking.
      final checkout = await _openCheckout(keyId, orderId, amountPaise);
      if (checkout.status != WalletTopUpStatus.success) {
        return WalletTopUpResult(
          status: checkout.status,
          message: checkout.message,
        );
      }

      // 3. Verify the signature server-side; the backend credits the wallet.
      final verifyRes = await client.post(
        '/wallet/verify-payment',
        body: {
          'razorpayOrderId': checkout.orderId,
          'razorpayPaymentId': checkout.paymentId,
          'razorpaySignature': checkout.signature,
          'customerId': customerId,
          'amountPaise': amountPaise,
        },
        timeout: const Duration(seconds: 30),
      );
      if (verifyRes.statusCode == 200) {
        final data = jsonDecode(verifyRes.body) as Map<String, dynamic>;
        final transaction = data['transaction'] as Map<String, dynamic>?;
        return WalletTopUpResult(
          status: WalletTopUpStatus.success,
          paymentId: checkout.paymentId,
          creditedPaise: (transaction?['amountPaise'] as num?)?.toInt(),
          balancePaise: (data['balancePaise'] as num?)?.toInt(),
          duplicate: data['duplicate'] == true,
        );
      }
      final code = _serverCode(verifyRes.body);
      final message = _serverError(
        verifyRes.body,
        'Payment verification failed',
      );
      if (code == 'payment_pending') {
        return WalletTopUpResult(
          status: WalletTopUpStatus.pending,
          message: message,
        );
      }
      if (code == 'payment_failed') {
        return WalletTopUpResult(
          status: WalletTopUpStatus.failed,
          message: message,
        );
      }
      return WalletTopUpResult(
        status: WalletTopUpStatus.error,
        message: message,
      );
    } catch (_) {
      return const WalletTopUpResult(
        status: WalletTopUpStatus.error,
        message: 'Payment Failed',
      );
    }
  }

  static Future<_CheckoutOutcome> _openCheckout(
    String keyId,
    String orderId,
    int amountPaise,
  ) {
    final completer = Completer<_CheckoutOutcome>();
    final razorpay = Razorpay();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      final paymentId = r.paymentId;
      final signature = r.signature;
      if (!completer.isCompleted) {
        if (paymentId == null ||
            paymentId.isEmpty ||
            signature == null ||
            signature.isEmpty) {
          completer.complete(
            const _CheckoutOutcome(
              WalletTopUpStatus.failed,
              'Payment response was incomplete',
            ),
          );
          return;
        }
        completer.complete(
          _CheckoutOutcome(
            WalletTopUpStatus.success,
            null,
            paymentId: paymentId,
            orderId: r.orderId ?? orderId,
            signature: signature,
          ),
        );
      }
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!completer.isCompleted) {
        if (r.code == Razorpay.PAYMENT_CANCELLED) {
          completer.complete(
            const _CheckoutOutcome(WalletTopUpStatus.cancelled, null),
          );
          return;
        }
        final message = r.message;
        completer.complete(
          _CheckoutOutcome(
            WalletTopUpStatus.failed,
            message != null && message.isNotEmpty ? message : 'Payment failed',
          ),
        );
      }
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
      if (!completer.isCompleted) {
        completer.complete(
          const _CheckoutOutcome(
            WalletTopUpStatus.failed,
            'Payment incomplete — please try again',
          ),
        );
      }
    });

    razorpay.open({
      'key': keyId,
      'amount': amountPaise,
      'currency': 'INR',
      'name': 'OXRO',
      'description': 'Wallet top-up',
      'order_id': orderId,
      'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
    });

    return completer.future
        .timeout(
          const Duration(seconds: 120),
          onTimeout: () => const _CheckoutOutcome(
            WalletTopUpStatus.failed,
            'Payment timed out',
          ),
        )
        .whenComplete(razorpay.clear);
  }

  static String _serverError(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        final error = (decoded['error'] as String).trim();
        if (error.isNotEmpty) return error;
      }
    } catch (_) {
      // Fall through to the fallback message.
    }
    return fallback;
  }

  static String? _serverCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['code'] is String) {
        return decoded['code'] as String;
      }
    } catch (_) {
      // No structured code.
    }
    return null;
  }
}

class _CheckoutOutcome {
  const _CheckoutOutcome(
    this.status,
    this.message, {
    this.paymentId,
    this.orderId,
    this.signature,
  });

  final WalletTopUpStatus status;
  final String? message;
  final String? paymentId;
  final String? orderId;
  final String? signature;
}
