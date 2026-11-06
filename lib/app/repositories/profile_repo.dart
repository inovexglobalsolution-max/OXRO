import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed profile sync. Login itself stays on-device.
class ProfileRepo {
  final ApiClient _client = ApiClient();

  /// Returns the stored profile map, or null when none exists/unreachable.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final id = CustomerIdentity.customerId;
    final res = await _client.get(
      '/profile/me?customerId=${Uri.encodeComponent(id)}',
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    final profile = decoded['profile'];
    return profile is Map<String, dynamic> ? profile : null;
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final res = await _client.put(
      '/profile/me',
      body: {...data, 'customerId': CustomerIdentity.customerId},
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> fetchPremium() async {
    final res = await _client.get(
      '/profile/premium?customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}',
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<Map<String, dynamic>?> joinPremium() async {
    final res = await _client.post(
      '/profile/premium/join',
      body: {'customerId': CustomerIdentity.customerId},
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<bool> cancelPremium() async {
    final res = await _client.post(
      '/profile/premium/cancel',
      body: {'customerId': CustomerIdentity.customerId},
    );
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>?> fetchPreferences() async {
    final res = await _client.get(
      '/profile/preferences?customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}',
    );
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<bool> savePreferences({
    required bool enabled,
    String? preference,
  }) async {
    final res = await _client.put(
      '/profile/preferences',
      body: {
        'customerId': CustomerIdentity.customerId,
        'enabled': enabled,
        'preference': preference,
      },
    );
    return res.statusCode == 200;
  }
}
