import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed orders. Local cache keeps the UI usable offline.
class OrderRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<List<dynamic>?> fetchOrders() async {
    try {
      final res = await _client.get('/orders?$_cid');
      if (res.statusCode != 200) {
        debugPrint('OrderRepo.fetchOrders: HTTP ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['orders'] is List ? decoded['orders'] as List : const [];
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.fetchOrders: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.fetchOrders: socket — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.fetchOrders: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchOrderById(String id) async {
    try {
      final res = await _client.get('/orders/${Uri.encodeComponent(id)}');
      if (res.statusCode != 200) {
        debugPrint('OrderRepo.fetchOrderById: HTTP ${res.statusCode}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['order'] is Map<String, dynamic>
          ? decoded['order'] as Map<String, dynamic>
          : null;
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.fetchOrderById: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.fetchOrderById: socket — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.fetchOrderById: $e');
      return null;
    }
  }

  Future<List<dynamic>> trackingSteps(String id) async {
    try {
      final res = await _client.get(
        '/orders/${Uri.encodeComponent(id)}/tracking',
      );
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      return decoded['steps'] is List ? decoded['steps'] as List : const [];
    } catch (e) {
      return const [];
    }
  }

  /// Places the order server-side. Returns the stored order map or null.
  Future<Map<String, dynamic>?> placeOrder(Map<String, dynamic> body) async {
    try {
      final res = await _client.post(
        '/checkout/place',
        body: {...body, 'customerId': CustomerIdentity.customerId},
        timeout: const Duration(seconds: 60),
      );
      if (res.statusCode != 201) {
        debugPrint('OrderRepo.placeOrder: HTTP ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['order'] is Map<String, dynamic>
          ? decoded['order'] as Map<String, dynamic>
          : null;
    } on TimeoutException catch (e) {
      debugPrint('OrderRepo.placeOrder: timeout — $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('OrderRepo.placeOrder: socket — $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('OrderRepo.placeOrder: bad JSON — $e');
      return null;
    } catch (e) {
      debugPrint('OrderRepo.placeOrder: $e');
      return null;
    }
  }

  Future<bool> cancelOrder(String id) async {
    try {
      final res = await _client.post(
        '/orders/${Uri.encodeComponent(id)}/cancel',
        body: {'customerId': CustomerIdentity.customerId},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
