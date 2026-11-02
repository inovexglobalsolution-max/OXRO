import '../api/api_client.dart';
import '../security/token_manager.dart';
import '../api/auth_interceptor.dart';

class RestaurantRepo {
  final ApiClient _client = ApiClient();
  final TokenManager _token = TokenManager();

  Future<List<dynamic>> fetchRestaurants() async {
    final headers = await AuthInterceptor().injectHeaders({});
    final response = await _client.get('/restaurants', headers: headers);
    return response.statusCode == 200 ? [] : [];
  }

  Future<List<dynamic>> fetchMenu(String restaurantId) async {
    final headers = await AuthInterceptor().injectHeaders({});
    final response = await _client.get('/restaurants/$restaurantId/menu', headers: headers);
    return response.statusCode == 200 ? [] : [];
  }
}
