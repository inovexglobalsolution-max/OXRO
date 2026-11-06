import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed notification inbox.
class NotificationRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      'customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<List<dynamic>?> list() async {
    final res = await _client.get('/notifications?$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded['notifications'] is List
        ? decoded['notifications'] as List
        : const [];
  }

  Future<bool> markRead(String id, {required bool unread}) async {
    final res = await _client.put(
      '/notifications/${Uri.encodeComponent(id)}/read',
      body: {'customerId': CustomerIdentity.customerId, 'unread': unread},
    );
    return res.statusCode == 200;
  }

  Future<bool> markAllRead() async {
    final res = await _client.put(
      '/notifications/read-all',
      body: {'customerId': CustomerIdentity.customerId},
    );
    return res.statusCode == 200;
  }
}
