import '../security/token_manager.dart';

class AuthInterceptor {
  final TokenManager _token = TokenManager();

  Future<Map<String, String>> injectHeaders(Map<String, String>? headers) async {
    final token = await _token.getAccessToken();
    final base = headers ?? {};
    base['Content-Type'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      base['Authorization'] = 'Bearer $token';
    }
    return base;
  }
}
