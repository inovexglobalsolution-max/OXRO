import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/location/data/geo_store.dart';

MockClient _client(Map<String, http.Response> byHost) {
  return MockClient((req) async {
    return byHost[req.url.host] ??
        http.Response('not found', 404);
  });
}

http.Response _ok(Map<String, dynamic> m) =>
    http.Response(jsonEncode(m), 200);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeoStore.resetForTests();
  });

  test('parsers accept valid payloads, reject junk', () {
    expect(
        GeoStore.parseIpapi({
          'country_code': 'IN',
          'country_name': 'India',
          'city': 'Chennai',
        })?.city,
        'Chennai');
    expect(GeoStore.parseIpapi({'country_code': '', 'country_name': ''}),
        isNull);
    expect(
        GeoStore.parseIpwho(
            {'success': false, 'country_code': 'IN', 'country': 'India'}),
        isNull);
    expect(
        GeoStore.parseIpwho({
          'success': true,
          'country_code': 'US',
          'country': 'United States',
          'city': 'Ashburn',
        })?.countryCode,
        'US');
    expect(
        GeoStore.parseGeojs({
          'country_code': 'IN',
          'country': 'India',
          'city': 'Madurai',
        })?.city,
        'Madurai');
    expect(GeoStore.parseGeojs({}), isNull);
  });

  test('GeoPoint India bbox', () {
    expect(const GeoPoint(13.08, 80.27).inIndia, isTrue); // Chennai
    expect(const GeoPoint(28.61, 77.20).inIndia, isTrue); // Delhi
    expect(const GeoPoint(0, 0).inIndia, isFalse);
    expect(const GeoPoint(40.7, -74.0).inIndia, isFalse); // NYC
  });

  test('cascade: ipapi fail falls through to ipwho', () async {
    GeoStore.gpsProbe = () async => null;
    GeoStore.instance.injectClientForTests(_client({
      'ipapi.co': http.Response('boom', 500),
      'ipwho.is': _ok({
        'success': true,
        'country_code': 'IN',
        'country': 'India',
        'city': 'Coimbatore',
      }),
    }));
    await GeoStore.instance.detect();
    expect(GeoStore.instance.place.city, 'Coimbatore');
    expect(GeoStore.instance.place.source, GeoSource.ipwho);
  });

  test('cascade: first success wins, later providers untouched',
      () async {
    var ipwhoCalls = 0;
    var geojsCalls = 0;
    GeoStore.gpsProbe = () async => null;
    GeoStore.instance.injectClientForTests(MockClient((req) async {
      if (req.url.host == 'ipapi.co') {
        return _ok({
          'country_code': 'IN',
          'country_name': 'India',
          'city': 'Trichy',
        });
      }
      if (req.url.host == 'ipwho.is') ipwhoCalls++;
      if (req.url.host == 'get.geojs.io') geojsCalls++;
      return http.Response('x', 500);
    }));
    await GeoStore.instance.detect();
    expect(GeoStore.instance.place.city, 'Trichy');
    expect(GeoStore.instance.place.source, GeoSource.ipapi);
    expect(ipwhoCalls, 0);
    expect(geojsCalls, 0);
  });

  test('all providers fail → India fallback (never throws)', () async {
    GeoStore.gpsProbe = () async => null;
    GeoStore.instance.injectClientForTests(
        _client(const {})); // every host 404
    await GeoStore.instance.detect();
    expect(GeoStore.instance.place.countryCode, 'IN');
    expect(GeoStore.instance.place.source, GeoSource.fallback);
  });

  test('GPS inside India wins when IP is dead', () async {
    GeoStore.gpsProbe =
        () async => const GeoPoint(13.08, 80.27);
    GeoStore.instance
        .injectClientForTests(_client(const {}));
    await GeoStore.instance.detect();
    expect(GeoStore.instance.place.source, GeoSource.gps);
    expect(GeoStore.instance.place.isIndia, isTrue);
  });

  test('GPS outside India falls through to IP', () async {
    GeoStore.gpsProbe =
        () async => const GeoPoint(40.7, -74.0);
    GeoStore.instance.injectClientForTests(_client({
      'ipapi.co': http.Response('boom', 500),
      'ipwho.is': _ok({
        'success': true,
        'country_code': 'US',
        'country': 'United States',
        'city': 'Ashburn',
      }),
    }));
    await GeoStore.instance.detect();
    expect(GeoStore.instance.place.countryCode, 'US');
    expect(GeoStore.instance.place.source, GeoSource.ipwho);
  });

  test('detection persists + reloads from cache', () async {
    GeoStore.gpsProbe = () async => null;
    GeoStore.instance.injectClientForTests(_client({
      'ipapi.co': _ok({
        'country_code': 'IN',
        'country_name': 'India',
        'city': 'Salem',
      }),
    }));
    await GeoStore.instance.detect();
    expect(GeoStore.instance.place.city, 'Salem');
    await Future.delayed(const Duration(milliseconds: 50));

    // Restart: memory wiped, prefs kept → cache hit, no network.
    var calls = 0;
    GeoStore.resetForTests();
    GeoStore.instance.injectClientForTests(
        MockClient((req) async {
      calls++;
      return http.Response('x', 500);
    }));
    await GeoStore.instance.load();
    expect(GeoStore.instance.place.city, 'Salem');
    expect(GeoStore.instance.place.source, GeoSource.cache);
    await GeoStore.instance.detect(); // done → skips network
    expect(calls, 0);
  });
}
