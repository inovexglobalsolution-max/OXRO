import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  /// Request timeout — 20s so a cold-starting free-tier backend (Render
  /// spins down after idle, ~30-60s warm-up) still answers instead of
  /// failing fast on a phone.
  static const Duration timeout = Duration(seconds: 20);

  /// Test hook — overrides the resolved base URL.
  @visibleForTesting
  static String? baseUrlOverride;

  String get baseUrl =>
      baseUrlOverride ??
      resolveBaseUrl(
        isAndroid: Platform.isAndroid,
        // `--dart-define=API_BASE_URL=http://192.168.1.5:5000`
        define: const String.fromEnvironment('API_BASE_URL'),
        env: Platform.environment['BASE_URL'],
      );

  /// Resolution order: dart-define → process env → platform default.
  /// Android emulators reach the host machine via `10.0.2.2`, not localhost.
  @visibleForTesting
  static String resolveBaseUrl({
    required bool isAndroid,
    String? define,
    String? env,
  }) {
    if (define != null && define.isNotEmpty) return define;
    if (env != null && env.isNotEmpty) return env;
    // Real device / emulator without dart-define: talk to the deployed backend
    // instead of the emulator-only 10.0.2.2 / localhost, which SocketException on
    // a real phone. Local dev still works via `--dart-define-from-file=env/dev.json`.
    return 'https://oxro-backend.onrender.com';
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {...?headers, 'Content-Type': 'application/json'},
        )
        .timeout(timeout ?? ApiClient.timeout);
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {...?headers, 'Content-Type': 'application/json'},
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(timeout ?? ApiClient.timeout);
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: {...?headers, 'Content-Type': 'application/json'},
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(timeout ?? ApiClient.timeout);
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return http
        .delete(
          Uri.parse('$baseUrl$path'),
          headers: {...?headers, 'Content-Type': 'application/json'},
        )
        .timeout(timeout ?? ApiClient.timeout);
  }
}
