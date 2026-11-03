import '../api/api_client.dart';
import '../api/auth_interceptor.dart';

class CartRepo {
  final ApiClient _client = ApiClient();

  Future<List<dynamic>> fetchCart() async {
    final headers = await AuthInterceptor().injectHeaders({});
    final response = await _client.get('/cart', headers: headers);
    return response.statusCode == 200
        ? (response.body.isNotEmpty ? [] : [])
        : [];
  }
}
