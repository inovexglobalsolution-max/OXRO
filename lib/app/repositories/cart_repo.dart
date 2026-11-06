import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed cart snapshot (local cart stays the instant UI cache).
class CartRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<Map<String, dynamic>?> fetchCart() async {
    final res = await _client.get('/cart?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Replaces the whole server cart with the current local snapshot.
  Future<bool> replaceCart({
    required List<Map<String, dynamic>> lines,
    required String instructions,
    required bool cutleryOptIn,
  }) async {
    final res = await _client.put(
      '/cart',
      body: {
        'customerId': CustomerIdentity.customerId,
        'lines': lines,
        'instructions': instructions,
        'cutleryOptIn': cutleryOptIn,
      },
    );
    return res.statusCode == 200;
  }

  Future<bool> clearCart() async {
    final res = await _client.delete('/cart?$_cid');
    return res.statusCode == 200;
  }
}
