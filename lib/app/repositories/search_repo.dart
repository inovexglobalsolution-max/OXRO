import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed catalogue search (callers keep a local fallback).
class ApiSearchRepo {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>?> search(String query, {int limit = 60}) async {
    final q = Uri.encodeComponent(query.trim());
    final res = await _client.get('/search?q=$q&limit=$limit');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  /// Recent search queries (newest first), or null when unreachable.
  Future<List<dynamic>?> fetchRecents() async {
    final res = await _client.get('/search/recents?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['queries'] is List ? decoded['queries'] as List : const [];
  }

  Future<bool> pushRecent(String query) async {
    final res = await _client.post(
      '/search/recents',
      body: {'customerId': CustomerIdentity.customerId, 'query': query},
    );
    return res.statusCode == 200;
  }

  Future<bool> removeRecent(String query) async {
    final res = await _client.delete(
      '/search/recents?$_cid&query=${Uri.encodeComponent(query)}',
    );
    return res.statusCode == 200;
  }

  Future<bool> clearRecents() async {
    final res = await _client.delete('/search/recents?$_cid');
    return res.statusCode == 200;
  }
}
