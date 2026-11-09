import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

enum ReservationPaymentStatus {
  success,
  cancelled,
  failed,
  pending,
  error,
  offline,
}

/// Outcome of a reservation platform-fee (₹7.00) payment.
class ReservationPaymentResult {
  const ReservationPaymentResult({
    required this.status,
    this.message,
    this.paymentId,
    this.booking,
    this.duplicate = false,
  });

  final ReservationPaymentStatus status;
  final String? message;
  final String? paymentId;
  final Map<String, dynamic>? booking;
  final bool duplicate;
}

/// Razorpay reservation platform-fee flow: create order → checkout → verify.
/// The reservation is only confirmed after backend verification. Online
/// methods only — COD is never offered.
class ReservationPayment {
  ReservationPayment._();

  static const int reservationFeePaise = 700; // ₹7.00

  /// Test seam — replaces the whole network + checkout flow.
  @visibleForTesting
  static Future<ReservationPaymentResult> Function({
    required String restaurantId,
    required int guests,
    required String slot,
  })?
  debugFlowOverride;

  /// True when a payment can actually be attempted.
  static bool get canAttemptPayment =>
      debugFlowOverride != null || CustomerIdentity.networkEnabled;

  static Future<ReservationPaymentResult> run({
    required String restaurantId,
    required int guests,
    required String slot,
    String? customerName,
    String? customerPhone,
    String? specialRequest,
  }) async {
    final override = debugFlowOverride;
    if (override != null) {
      return override(restaurantId: restaurantId, guests: guests, slot: slot);
    }
    if (!CustomerIdentity.networkEnabled) {
      return const ReservationPaymentResult(
        status: ReservationPaymentStatus.offline,
      );
    }

    final client = ApiClient();
    final customerId = CustomerIdentity.customerId;
    try {
      // 1. Server creates the Razorpay order — amount is fixed server-side.
      final createRes = await client.post(
        '/dineout/bookings/create-payment-order',
        body: {'customerId': customerId},
        timeout: const Duration(seconds: 30),
      );
      if (createRes.statusCode != 201) {
        return ReservationPaymentResult(
          status: ReservationPaymentStatus.error,
          message: _serverError(createRes.body, 'Could not start payment'),
        );
      }
      final created = jsonDecode(createRes.body) as Map<String, dynamic>;
      final keyId = created['keyId'] as String?;
      final orderId = created['razorpayOrderId'] as String?;
      final amount = created['amount'] as int?;
      if (keyId == null || orderId == null || amount == null) {
        return const ReservationPaymentResult(
          status: ReservationPaymentStatus.error,
          message: 'Could not start payment',
        );
      }

      // 2. Open checkout — online methods only, never COD.
      final checkout = await _openCheckout(keyId, orderId, amount);
      if (checkout.status != ReservationPaymentStatus.success) {
        return ReservationPaymentResult(
          status: checkout.status,
          message: checkout.message,
        );
      }

      // 3. Backend verifies payment and confirms the reservation.
      final body = <String, dynamic>{
        'razorpayOrderId': checkout.orderId,
        'razorpayPaymentId': checkout.paymentId,
        'razorpaySignature': checkout.signature,
        'restaurantId': restaurantId,
        'guests': guests,
        'slot': slot,
        'customerId': customerId,
      };
      if (customerName != null) body['customerName'] = customerName;
      if (customerPhone != null) body['customerPhone'] = customerPhone;
      if (specialRequest != null) body['specialRequest'] = specialRequest;
      final confirmRes = await client.post(
        '/dineout/bookings/confirm-booking',
        body: body,
        timeout: const Duration(seconds: 30),
      );
      if (confirmRes.statusCode == 201) {
        final data = jsonDecode(confirmRes.body) as Map<String, dynamic>;
        return ReservationPaymentResult(
          status: ReservationPaymentStatus.success,
          paymentId: checkout.paymentId,
          booking: data['booking'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['booking'] as Map)
              : null,
          duplicate: data['duplicate'] == true,
        );
      }
      final code = _serverCode(confirmRes.body);
      final message = _serverError(
        confirmRes.body,
        'Payment verification failed',
      );
      if (code == 'payment_pending') {
        return ReservationPaymentResult(
          status: ReservationPaymentStatus.pending,
          message: message,
        );
      }
      if (code == 'payment_failed') {
        return ReservationPaymentResult(
          status: ReservationPaymentStatus.failed,
          message: message,
        );
      }
      return ReservationPaymentResult(
        status: ReservationPaymentStatus.error,
        message: message,
      );
    } catch (_) {
      return const ReservationPaymentResult(
        status: ReservationPaymentStatus.error,
        message: 'Payment Failed',
      );
    }
  }

  static Future<_CheckoutOutcome> _openCheckout(
    String keyId,
    String orderId,
    int amount,
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
              ReservationPaymentStatus.failed,
              'Payment response was incomplete',
            ),
          );
          return;
        }
        completer.complete(
          _CheckoutOutcome(
            ReservationPaymentStatus.success,
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
            const _CheckoutOutcome(ReservationPaymentStatus.cancelled, null),
          );
          return;
        }
        final message = r.message;
        completer.complete(
          _CheckoutOutcome(
            ReservationPaymentStatus.failed,
            message != null && message.isNotEmpty ? message : 'Payment failed',
          ),
        );
      }
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
      if (!completer.isCompleted) {
        completer.complete(
          const _CheckoutOutcome(
            ReservationPaymentStatus.failed,
            'Payment incomplete — please try again',
          ),
        );
      }
    });

    razorpay.open({
      'key': keyId,
      'amount': amount,
      'currency': 'INR',
      'name': 'OXRO',
      'description': 'Reservation platform fee',
      'order_id': orderId,
      'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
    });

    return completer.future
        .timeout(
          const Duration(seconds: 120),
          onTimeout: () => const _CheckoutOutcome(
            ReservationPaymentStatus.failed,
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

  final ReservationPaymentStatus status;
  final String? message;
  final String? paymentId;
  final String? orderId;
  final String? signature;
}
