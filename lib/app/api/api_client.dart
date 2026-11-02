import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiClient {
  String get baseUrl => Platform.environment['BASE_URL'] ?? 'http://localhost:5000';

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return http.get(
      Uri.parse('$baseUrl$path'),
      headers: {...?headers, 'Content-Type': 'application/json'},
    );
  }

  Future<http.Response> post(String path, {Object? body, Map<String, String>? headers}) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: {...?headers, 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
