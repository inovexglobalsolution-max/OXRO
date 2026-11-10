import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:oxro/app/api/api_client.dart';
import 'package:oxro/app/api/customer_identity.dart';

class AuthRepo {
  final ApiClient _client = ApiClient();

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> sendOtp(String email) async {
    if (!CustomerIdentity.networkEnabled) return null;
    try {
      final res = await _client.post(
        '/auth/send-otp',
        body: {'email': email.trim()},
      );
      if (res.statusCode == 200) return null;
      return _errorFrom(res, 'Could not send OTP — try again');
    } on TimeoutException {
      return 'Server is taking too long — try again';
    } catch (_) {
      return 'Could not reach server — check connection';
    }
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> verifyOtp({
    required String email,
    required String token,
    String? name,
  }) async {
    if (!CustomerIdentity.networkEnabled) return null;
    try {
      final res = await _client.post(
        '/auth/verify-otp',
        body: {
          'email': email.trim(),
          'token': token.trim(),
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      if (res.statusCode == 200) return null;
      return _errorFrom(res, 'Invalid or expired code');
    } on TimeoutException {
      return 'Server is taking too long — try again';
    } catch (_) {
      return 'Could not reach server — check connection';
    }
  }

  String _errorFrom(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] is String) {
        final msg = (decoded['error'] as String).trim();
        if (msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    return fallback;
  }
}
