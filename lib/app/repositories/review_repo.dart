import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed user reviews (one per product).
class ReviewRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<List<dynamic>?> list() async {
    final res = await _client.get('/reviews?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['reviews'] is List ? decoded['reviews'] as List : const [];
  }

  /// Upserts the customer's review for [productId].
  Future<bool> upsert({
    required int productId,
    required int rating,
    required String body,
    List<int> photos = const [],
    bool hasVideo = false,
  }) async {
    final res = await _client.post(
      '/reviews',
      body: {
        'customerId': CustomerIdentity.customerId,
        'productId': productId,
        'rating': rating,
        'body': body,
        'photos': photos,
        'hasVideo': hasVideo,
      },
    );
    return res.statusCode == 201;
  }
}
