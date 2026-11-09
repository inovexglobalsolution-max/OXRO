import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed support tickets (Bag Help / order issues).
class SupportRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<List<dynamic>?> list() async {
    final res = await _client.get('/support/tickets?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['tickets'] is List ? decoded['tickets'] as List : const [];
  }

  Future<bool> create(Map<String, dynamic> data) async {
    final res = await _client.post(
      '/support/tickets',
      body: {...data, 'customerId': CustomerIdentity.customerId},
    );
    return res.statusCode == 201;
  }

  /// Role-scoped FAQ knowledge base (chatbot phase 1).
  Future<List<dynamic>> faqs({String role = 'customer'}) async {
    if (!CustomerIdentity.networkEnabled) return const [];
    try {
      final res = await _client.get('/support/faqs?role=$role');
      if (res.statusCode != 200) return const [];
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return const [];
      return decoded['faqs'] is List ? decoded['faqs'] as List : const [];
    } catch (_) {
      return const [];
    }
  }
}
