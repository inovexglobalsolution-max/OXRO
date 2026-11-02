import '../security/token_manager.dart';
import '../models/auth_models.dart';

class AuthRepo {
  final TokenManager _token = TokenManager();

  Future<bool> isLoggedIn() async => (await _token.getAccessToken()) != null;

  Future<LoginResponse?> login(LoginRequest req) async {
    await _token.saveTokens(access: 'mock-access', refresh: 'mock-refresh');
    return LoginResponse(token: 'mock-access', refreshToken: 'mock-refresh');
  }

  Future<void> logout() async => await _token.clearTokens();
}
