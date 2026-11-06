import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed promo coupons (local list stays the fallback).
class CouponRepo {
  final ApiClient _client = ApiClient();

  Future<List<dynamic>?> list() async {
    final res = await _client.get('/coupons');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['coupons'] is List ? decoded['coupons'] as List : const [];
  }
}

/// Server-backed dineout table bookings.
class BookingRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<List<dynamic>?> list() async {
    final res = await _client.get('/dineout/bookings?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['bookings'] is List ? decoded['bookings'] as List : const [];
  }

  Future<bool> create({
    required String restaurantId,
    required int guests,
    required String slot,
    String? note,
  }) async {
    final res = await _client.post(
      '/dineout/bookings',
      body: {
        'customerId': CustomerIdentity.customerId,
        'restaurantId': restaurantId,
        'guests': guests,
        'slot': slot,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return res.statusCode == 201;
  }
}
