import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
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

  static const _googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  bool _googleReady = false;

  /// Interactive Google sign-in. Returns `(error, email, name)` — exactly one
  /// of error/email is non-null.
  Future<(String?, String?, String?)> googleSignIn() async {
    if (!CustomerIdentity.networkEnabled) {
      return (null, 'test@example.com', 'Test User');
    }
    if (_googleServerClientId.isEmpty) {
      return ('Google sign-in is not configured', null, null);
    }
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleServerClientId,
        );
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return ('Could not get Google token', null, null);
      }
      final res = await _client.post(
        '/auth/google',
        body: {'idToken': idToken},
      );
      if (res.statusCode != 200) {
        return (_errorFrom(res, 'Google sign-in failed'), null, null);
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final email = decoded['email'] as String?;
      final name = decoded['name'] as String?;
      return (null, email, name);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return ('Google sign-in cancelled', null, null);
      }
      return ('Google sign-in failed — try again', null, null);
    } on TimeoutException {
      return ('Server is taking too long — try again', null, null);
    } catch (_) {
      return ('Could not reach server — check connection', null, null);
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
