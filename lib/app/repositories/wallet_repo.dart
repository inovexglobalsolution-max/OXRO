import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed OXRO Money ledger. Top-up is intentionally absent until
/// a real payment gateway exists.
class WalletRepo {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>?> fetchLedger() async {
    final id = CustomerIdentity.customerId;
    final res = await _client.get(
      '/wallet?customerId=${Uri.encodeComponent(id)}',
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
