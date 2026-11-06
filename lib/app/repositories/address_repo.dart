import 'dart:convert';

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

/// Server-backed address book (local store remains the offline cache).
class AddressRepo {
  final ApiClient _client = ApiClient();

  static String get _cid =>
      '?customerId=${Uri.encodeComponent(CustomerIdentity.customerId)}';

  Future<Map<String, dynamic>?> fetchAddresses() async {
    final res = await _client.get('/addresses$_cid');
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<Map<String, dynamic>?> createAddress(Map<String, dynamic> data) async {
    final res = await _client.post(
      '/addresses',
      body: {...data, 'customerId': CustomerIdentity.customerId},
    );
    if (res.statusCode != 201 && res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<bool> updateAddress(String id, Map<String, dynamic> data) async {
    final res = await _client.put(
      '/addresses/${Uri.encodeComponent(id)}',
      body: {...data, 'customerId': CustomerIdentity.customerId},
    );
    return res.statusCode == 200;
  }

  Future<bool> selectAddress(String id) async {
    final res = await _client.post(
      '/addresses/${Uri.encodeComponent(id)}/select',
      body: {'customerId': CustomerIdentity.customerId},
    );
    return res.statusCode == 200;
  }

  Future<bool> deleteAddress(String id) async {
    final res = await _client.delete(
      '/addresses/${Uri.encodeComponent(id)}$_cid',
    );
    return res.statusCode == 200;
  }
}
