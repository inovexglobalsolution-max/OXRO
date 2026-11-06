import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/auth_interceptor.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-confirmed Smart Change activation.
class SmartChangeActivation {
  const SmartChangeActivation({
    required this.txnId,
    required this.orderAmountPaise,
    required this.cashAmountPaise,
    required this.remainingChangePaise,
    this.orderId,
  });

  final String txnId;
  final int orderAmountPaise;
  final int cashAmountPaise;
  final int remainingChangePaise;

  /// Placed order id once linked (delivery partner display).
  final String? orderId;
}

/// A credited Smart Change transaction awaiting local wallet application.
class SmartChangeCredit {
  const SmartChangeCredit({
    required this.txnId,
    required this.orderId,
    required this.walletCreditPaise,
    required this.walletTransactionId,
  });

  final String txnId;
  final String orderId;
  final int walletCreditPaise;
  final String walletTransactionId;
}

/// Thrown when the Smart Change backend rejects a call (or is down).
class SmartChangeException implements Exception {
  const SmartChangeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the `/smart-change` endpoints.
///
/// Test hooks ([activateOverride], [linkOverride], [creditsOverride])
/// let widget tests run without a server (PaymentGateway pattern).
class SmartChangeRepo {
  SmartChangeRepo._();

  static final SmartChangeRepo instance = SmartChangeRepo._();

  final ApiClient _client = ApiClient();
  static final Random _rand = Random();

  @visibleForTesting
  static Future<SmartChangeActivation> Function({
    required int orderAmountPaise,
    required int cashAmountPaise,
    required String customerId,
    required String idempotencyKey,
  })?
  activateOverride;

  @visibleForTesting
  static Future<void> Function(String txnId, String orderId)? linkOverride;

  @visibleForTesting
  static Future<List<SmartChangeCredit>> Function(String customerId)?
  creditsOverride;

  @visibleForTesting
  static Future<SmartChangeActivation> Function({
    required String txnId,
    required int actualCashPaise,
    required String partnerId,
  })?
  collectOverride;

  @visibleForTesting
  static Future<SmartChangeActivation> Function(String txnId)? getOverride;

  @visibleForTesting
  static Future<List<SmartChangeActivation>> Function()? collectableOverride;

  /// Stable customer id shared with every other API (phone/email, else guest).
  static String get currentCustomerId => CustomerIdentity.customerId;

  /// One idempotency key per consent session (double-tap safe).
  /// NOTE: `1 << 32` overflows to 0 on web (JS 32-bit shifts) — keep the
  /// bound within int32 so `nextInt` never throws in browser builds.
  static String newIdempotencyKey() =>
      'sc-${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(0x7fffffff)}';

  /// Activates the consent server-side. Throws [SmartChangeException]
  /// on any failure — callers must NOT show success on error.
  Future<SmartChangeActivation> activate({
    required int orderAmountPaise,
    required int cashAmountPaise,
    required String customerId,
    required String idempotencyKey,
  }) async {
    final override = activateOverride;
    if (override != null) {
      return override(
        orderAmountPaise: orderAmountPaise,
        cashAmountPaise: cashAmountPaise,
        customerId: customerId,
        idempotencyKey: idempotencyKey,
      );
    }
    try {
      final headers = await AuthInterceptor().injectHeaders({});
      final res = await _client.post(
        '/smart-change/activate',
        headers: headers,
        body: {
          'customerId': customerId,
          'orderAmountPaise': orderAmountPaise,
          'cashAmountPaise': cashAmountPaise,
          'idempotencyKey': idempotencyKey,
        },
        timeout: const Duration(seconds: 60),
      );
      final m = _json(res.body);
      if (res.statusCode != 200 && res.statusCode != 201) {
        debugPrint(
          'SmartChangeRepo.activate: HTTP ${res.statusCode} ${res.body}',
        );
        throw SmartChangeException(
          (m['error'] as String?) ?? 'Smart Change activation failed',
        );
      }
      return SmartChangeActivation(
        txnId: (m['txnId'] as String?) ?? '',
        orderAmountPaise: _int(m['orderAmountPaise']),
        cashAmountPaise: _int(m['declaredCashPaise']),
        remainingChangePaise: _int(m['remainingChangePaise']),
      );
    } on TimeoutException catch (e) {
      debugPrint('SmartChangeRepo.activate: timeout — $e');
      throw const SmartChangeException(
        'OXRO Smart Change server is not responding. Check that the backend is running and try again.',
      );
    } on SocketException catch (e) {
      debugPrint('SmartChangeRepo.activate: socket — $e');
      throw const SmartChangeException(
        'Could not reach OXRO Smart Change. Please try again.',
      );
    } on FormatException catch (e) {
      debugPrint('SmartChangeRepo.activate: bad JSON — $e');
      throw const SmartChangeException('Smart Change activation failed');
    } catch (e) {
      debugPrint('SmartChangeRepo.activate: $e');
      throw SmartChangeException('Smart Change activation failed: $e');
    }
  }

  /// Links the activated transaction to the placed order id.
  Future<void> linkOrder({
    required String txnId,
    required String orderId,
  }) async {
    final override = linkOverride;
    if (override != null) return override(txnId, orderId);
    final headers = await AuthInterceptor().injectHeaders({});
    final res = await _client.post(
      '/smart-change/$txnId/link-order',
      headers: headers,
      body: {'orderId': orderId},
    );
    if (res.statusCode != 200) {
      final m = _json(res.body);
      throw SmartChangeException(
        (m['error'] as String?) ?? 'Could not link Smart Change to this order',
      );
    }
  }

  /// Credited transactions for this customer (wallet application step).
  Future<List<SmartChangeCredit>> credited(String customerId) async {
    final override = creditsOverride;
    if (override != null) return override(customerId);
    final headers = await AuthInterceptor().injectHeaders({});
    final res = await _client.get(
      '/smart-change/credited?customerId=${Uri.encodeComponent(customerId)}',
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw SmartChangeException('Could not fetch Smart Change credits');
    }
    final m = _json(res.body);
    final list = m['transactions'] is List
        ? m['transactions'] as List
        : const [];
    return [
      for (final e in list)
        SmartChangeCredit(
          txnId: (e['txnId'] as String?) ?? '',
          orderId: (e['orderId'] as String?) ?? '',
          walletCreditPaise: _int(e['remainingChangePaise']),
          walletTransactionId: (e['walletTransactionId'] as String?) ?? '',
        ),
    ];
  }

  /// Smart Change COD orders a delivery partner can collect.
  Future<List<SmartChangeActivation>> collectable() async {
    final override = collectableOverride;
    if (override != null) return override();
    final headers = await AuthInterceptor().injectHeaders({});
    final res = await _client.get(
      '/smart-change/collectable',
      headers: headers,
    );
    if (res.statusCode != 200) {
      throw const SmartChangeException('Could not fetch COD collections');
    }
    final m = _json(res.body);
    final list = m['transactions'] is List
        ? m['transactions'] as List
        : const [];
    return [
      for (final e in list)
        SmartChangeActivation(
          txnId: (e['txnId'] as String?) ?? '',
          orderAmountPaise: _int(e['orderAmountPaise']),
          cashAmountPaise: _int(e['declaredCashPaise']),
          remainingChangePaise: _int(e['remainingChangePaise']),
          orderId: (e['orderId'] as String?) ?? '',
        ),
    ];
  }

  /// Fetches a transaction (delivery partner open — declared cash etc).
  Future<SmartChangeActivation> get(String txnId) async {
    final override = getOverride;
    if (override != null) return override(txnId);
    final headers = await AuthInterceptor().injectHeaders({});
    final res = await _client.get('/smart-change/$txnId', headers: headers);
    final m = _json(res.body);
    if (res.statusCode != 200) {
      throw SmartChangeException(
        (m['error'] as String?) ?? 'Smart Change transaction not found',
      );
    }
    return SmartChangeActivation(
      txnId: (m['txnId'] as String?) ?? txnId,
      orderAmountPaise: _int(m['orderAmountPaise']),
      cashAmountPaise: _int(m['declaredCashPaise']),
      remainingChangePaise: _int(m['remainingChangePaise']),
      orderId: (m['orderId'] as String?) ?? '',
    );
  }

  /// Delivery partner confirms the collected cash. The backend verifies
  /// the amount and credits the change server-side; a wallet-credit
  /// failure throws [SmartChangeException] with the support instruction.
  Future<SmartChangeActivation> collect({
    required String txnId,
    required int actualCashPaise,
    required String partnerId,
  }) async {
    final override = collectOverride;
    if (override != null) {
      return override(
        txnId: txnId,
        actualCashPaise: actualCashPaise,
        partnerId: partnerId,
      );
    }
    final headers = await AuthInterceptor().injectHeaders({});
    final res = await _client.post(
      '/smart-change/$txnId/collect',
      headers: headers,
      body: {'partnerId': partnerId, 'actualCashPaise': actualCashPaise},
    );
    final m = _json(res.body);
    if (res.statusCode != 200) {
      throw SmartChangeException(
        (m['error'] as String?) ??
            'Cash verification failed — return the physical change to '
                'the customer or contact OXRO support.',
      );
    }
    return SmartChangeActivation(
      txnId: (m['txnId'] as String?) ?? txnId,
      orderAmountPaise: _int(m['orderAmountPaise']),
      cashAmountPaise: _int(m['actualCashPaise']),
      remainingChangePaise: _int(m['remainingChangePaise']),
      orderId: (m['orderId'] as String?) ?? '',
    );
  }

  static Map<String, dynamic> _json(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return <String, dynamic>{};
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
}
