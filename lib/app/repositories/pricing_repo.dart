import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';

/// Server-backed pricing configuration (local store stays the fallback).
class PricingRepo {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>?> fetchConfig() async {
    final res = await _client.get('/pricing');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['config'] is Map<String, dynamic>
        ? decoded['config'] as Map<String, dynamic>
        : null;
  }

  Future<bool> updateConfig(Map<String, dynamic> config) async {
    final res = await _client.put('/pricing', body: config);
    return res.statusCode == 200;
  }
}
