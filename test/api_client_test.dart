import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/api/api_client.dart';

void main() {
  group('ApiClient.resolveBaseUrl', () {
    test('dart-define wins over env and platform default', () {
      expect(
        ApiClient.resolveBaseUrl(
          isAndroid: true,
          define: 'http://192.168.1.5:5000',
          env: 'http://localhost:9000',
        ),
        'http://192.168.1.5:5000',
      );
    });

    test('process env wins over platform default', () {
      expect(
        ApiClient.resolveBaseUrl(isAndroid: true, env: 'http://localhost:9000'),
        'http://localhost:9000',
      );
    });

    test('ignore blank define/env', () {
      expect(
        ApiClient.resolveBaseUrl(isAndroid: false, define: '', env: ''),
        'https://oxro-backend.onrender.com',
      );
    });

    test('default platform fallback is the deployed backend URL', () {
      expect(
        ApiClient.resolveBaseUrl(isAndroid: true),
        'https://oxro-backend.onrender.com',
      );
      expect(
        ApiClient.resolveBaseUrl(isAndroid: false),
        'https://oxro-backend.onrender.com',
      );
    });
  });

  test('baseUrlOverride wins over resolution', () {
    ApiClient.baseUrlOverride = 'http://test.local:1234';
    addTearDown(() => ApiClient.baseUrlOverride = null);
    expect(ApiClient().baseUrl, 'http://test.local:1234');
  });
}
