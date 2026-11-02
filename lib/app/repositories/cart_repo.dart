import '../api/api_client.dart';
import '../security/token_manager.dart';

class CartRepo {
  final ApiClient _client = ApiClient();
  final TokenManager _token = TokenManager();

  Future<List<dynamic>> fetchCart() async {
    final headers = await AuthInterceptor().injectHeaders({});
    final response = await _client.get('/cart', headers: headers);
    return response.statusCode == 200 ? (response.body.isNotEmpty ? [] : []) : [];
  }
}
