import '../api/api_client.dart';
import '../api/auth_interceptor.dart';

class PricingRepo {
  final ApiClient _client = ApiClient();

  Future<dynamic> fetchConfig() async {
    final headers = await AuthInterceptor().injectHeaders({});
    return await _client.get('/pricing', headers: headers);
  }

  Future<dynamic> updateConfig(Map<String, dynamic> config) async {
    final headers = await AuthInterceptor().injectHeaders({});
    return await _client.post('/pricing', body: config, headers: headers);
  }
}
