import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  static const _accessKey = 'oxro_access_token';
  static const _refreshKey = 'oxro_refresh_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getAccessToken() async => await _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() async => await _storage.read(key: _refreshKey);

  Future<void> saveTokens({String? access, String? refresh}) async {
    if (access != null) await _storage.write(key: _accessKey, value: access);
    if (refresh != null) await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
