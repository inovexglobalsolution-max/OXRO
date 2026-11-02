import '../api/api_client.dart';
import '../api/auth_interceptor.dart';

class WalletRepo {
  final ApiClient _client = ApiClient();

  Future<dynamic> fetchBalance() async {
    final headers = await AuthInterceptor().injectHeaders({});
    return await _client.get('/wallet', headers: headers);
  }

  Future<dynamic> addMoney(int amount) async {
    final headers = await AuthInterceptor().injectHeaders({});
    return await _client.post('/wallet/add', body: {'amount': amount}, headers: headers);
  }
}
