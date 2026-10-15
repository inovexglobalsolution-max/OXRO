import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the location came from (VPN-project cascade, Flutter port).
enum GeoSource { cache, gps, ipapi, ipwho, geojs, fallback }

/// Detected delivery location. Prices stay ₹ (India-only app) —
/// this drives the location card + address prefill only.
class GeoPlace {
  const GeoPlace({
    required this.countryCode,
    required this.countryName,
    this.city,
    required this.source,
  });

  final String countryCode;
  final String countryName;
  final String? city;
  final GeoSource source;

  static const india =
      GeoPlace(countryCode: 'IN', countryName: 'India', source: GeoSource.fallback);

  bool get isIndia => countryCode.toUpperCase() == 'IN';

  String get displayLine {
    final c = (city ?? '').trim();
    if (c.isNotEmpty) return '$c, $countryName';
    return countryName;
  }

  Map<String, dynamic> toJson() => {
        'countryCode': countryCode,
        'countryName': countryName,
        'city': city,
        'source': source.name,
      };

  static GeoPlace? fromJson(Map<String, dynamic> m) {
    final code = (m['countryCode'] as String?)?.trim() ?? '';
    final name = (m['countryName'] as String?)?.trim() ?? '';
    if (code.isEmpty || name.isEmpty) return null;
    final src = m['source'] as String?;
    return GeoPlace(
      countryCode: code,
      countryName: name,
      city: (m['city'] as String?)?.trim(),
      source: GeoSource.values.cast<GeoSource?>().firstWhere(
            (s) => s?.name == src,
            orElse: () => null,
          ) ??
          GeoSource.cache,
    );
  }
}

/// GPS point (own type so tests can inject probes without geolocator).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  /// Rough India bounding box (GPS can't reverse-geocode offline —
  /// inside the box counts as an India fix; city comes from IP).
  bool get inIndia =>
      lat >= 6.5 &&
      lat <= 37.5 &&
      lng >= 67.5 &&
      lng <= 97.5;
}

/// Delivery-location detection: GPS first, then IP cascade
/// ipapi.co → ipwho.is → geojs.io, cached on device.
/// Silent fallbacks everywhere — never throws, never blocks UI.
class GeoStore extends ChangeNotifier {
  GeoStore._();

  /// Global instance (tests drive via [resetForTests] + seams below).
  static final GeoStore instance = GeoStore._();

  static const _kCache = 'oxro_detected_country';

  /// Test seam: replaces the real GPS probe (permission dialogs
  /// can't run in widget tests). Null = use geolocator.
  @visibleForTesting
  static Future<GeoPoint?> Function()? gpsProbe;

  @visibleForTesting
  static void resetForTests() {
    gpsProbe = null;
    instance._place = GeoPlace.india;
    instance._detecting = false;
    instance._done = false;
    instance._client?.close();
    instance._client = null;
    instance.notifyListeners();
  }

  http.Client? _client;
  GeoPlace _place = GeoPlace.india;
  bool _detecting = false;
  bool _done = false;

  GeoPlace get place => _place;
  bool get detecting => _detecting;
  String? get city => _place.city;

  /// Injectable HTTP client (tests pass a fake; app uses real).
  @visibleForTesting
  void injectClientForTests(http.Client client) {
    _client?.close();
    _client = client;
  }

  http.Client get _http => _client ??= http.Client();

  /// Loads cached detection (call once at splash; instant).
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final place =
          GeoPlace.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (place == null) return;
      _place = GeoPlace(
        countryCode: place.countryCode,
        countryName: place.countryName,
        city: place.city,
        source: GeoSource.cache,
      );
      _done = true;
      notifyListeners();
    } catch (_) {
      // Best-effort cache only.
    }
  }

  Future<void> _persist(GeoPlace place) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kCache, jsonEncode(place.toJson()));
    } catch (_) {
      // Best-effort cache only.
    }
  }

  /// Runs the cascade once (skips when already resolved).
  /// Set [force] to re-detect (e.g. pull-to-refresh later).
  Future<void> detect({bool force = false}) async {
    if (_done && !force) return;
    if (_detecting) return;
    _detecting = true;
    notifyListeners();
    try {
      // 1. GPS first (fast fail on denied/off).
      final gps = await _tryGps();
      // 2. IP cascade for city-level detail.
      final ip = await _tryIpCascade();
      final win = ip ?? gps ?? GeoPlace.india;
      _place = win;
      _done = true;
      notifyListeners();
      if (win.source != GeoSource.fallback) _persist(win);
    } finally {
      _detecting = false;
      notifyListeners();
    }
  }

  Future<GeoPlace?> _tryGps() async {
    try {
      final probe = gpsProbe;
      if (probe != null) {
        final pt = await probe().timeout(
            const Duration(seconds: 5));
        if (pt == null || !pt.inIndia) return null;
        return const GeoPlace(
            countryCode: 'IN',
            countryName: 'India',
            source: GeoSource.gps);
      }
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 6),
        ),
      ).timeout(const Duration(seconds: 8));
      final pt = GeoPoint(pos.latitude, pos.longitude);
      if (!pt.inIndia) return null;
      return const GeoPlace(
          countryCode: 'IN',
          countryName: 'India',
          source: GeoSource.gps);
    } catch (_) {
      return null;
    }
  }

  Future<GeoPlace?> _tryIpCascade() async {
    return await _viaIpapi() ??
        await _viaIpwho() ??
        await _viaGeojs();
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    try {
      final res = await _http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body);
      if (m is! Map<String, dynamic>) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  /// Pure parsers (unit-tested, no network).
  @visibleForTesting
  static GeoPlace? parseIpapi(Map<String, dynamic> m) {
    final code = (m['country_code'] as String?)?.trim() ?? '';
    final name = (m['country_name'] as String?)?.trim() ?? '';
    if (code.isEmpty || name.isEmpty) return null;
    return GeoPlace(
      countryCode: code,
      countryName: name,
      city: (m['city'] as String?)?.trim(),
      source: GeoSource.ipapi,
    );
  }

  @visibleForTesting
  static GeoPlace? parseIpwho(Map<String, dynamic> m) {
    final ok = m['success'];
    if (ok is bool && !ok) return null;
    final code = (m['country_code'] as String?)?.trim() ?? '';
    final name = (m['country'] as String?)?.trim() ?? '';
    if (code.isEmpty || name.isEmpty) return null;
    return GeoPlace(
      countryCode: code,
      countryName: name,
      city: (m['city'] as String?)?.trim(),
      source: GeoSource.ipwho,
    );
  }

  @visibleForTesting
  static GeoPlace? parseGeojs(Map<String, dynamic> m) {
    final code = (m['country_code'] as String?)?.trim() ?? '';
    final name = (m['country'] as String?)?.trim() ?? '';
    if (code.isEmpty || name.isEmpty) return null;
    return GeoPlace(
      countryCode: code,
      countryName: name,
      city: (m['city'] as String?)?.trim(),
      source: GeoSource.geojs,
    );
  }

  Future<GeoPlace?> _viaIpapi() async {
    final m = await _getJson('https://ipapi.co/json/');
    if (m == null) return null;
    return parseIpapi(m);
  }

  Future<GeoPlace?> _viaIpwho() async {
    final m = await _getJson('https://ipwho.is/');
    if (m == null) return null;
    return parseIpwho(m);
  }

  Future<GeoPlace?> _viaGeojs() async {
    final m =
        await _getJson('https://get.geojs.io/v1/ip/geo.json');
    if (m == null) return null;
    return parseGeojs(m);
  }
}
