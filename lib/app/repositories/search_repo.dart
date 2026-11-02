import '../api/api_client.dart';
import '../api/auth_interceptor.dart';

class SearchRepo {
  final ApiClient _client = ApiClient();

  Future<dynamic> search(String q) async {
    final headers = await AuthInterceptor().injectHeaders({});
    return await _client.get('/search?q=$q', headers: headers);
  }
}
