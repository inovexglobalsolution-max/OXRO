import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed wishlist (local store stays the instant cache).
class WishlistRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  /// Returns the customer's saved products, or null when unreachable.
  Future<List<dynamic>?> list() async {
    final res = await _client.get('/wishlist?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['items'] is List ? decoded['items'] as List : const [];
  }

  /// Adds a product; returns the fresh list or null when unreachable.
  Future<List<dynamic>?> add(Map<String, dynamic> product) async {
    final res = await _client.post(
      '/wishlist',
      body: {'customerId': CustomerIdentity.customerId, 'product': product},
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['items'] is List ? decoded['items'] as List : const [];
  }

  Future<List<dynamic>?> remove(int productId) async {
    final res = await _client.delete('/wishlist/$productId?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['items'] is List ? decoded['items'] as List : const [];
  }
}
