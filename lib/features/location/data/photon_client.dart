import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One Photon (photon.komoot.io) search/reverse result.
class PhotonSuggestion {
  const PhotonSuggestion({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.line,
    this.city,
    this.state,
    this.pin,
  });

  final double latitude;
  final double longitude;
  final String displayName;
  final String? line;
  final String? city;
  final String? state;
  final String? pin;

  factory PhotonSuggestion.fromFeature(Map<String, dynamic> feature) {
    final geo = feature['geometry'] as Map<String, dynamic>?;
    final coords = (geo?['coordinates'] as List?) ?? const [];
    final lng = coords.isNotEmpty ? coords[0] as num? : null;
    final lat = coords.length > 1 ? coords[1] as num? : null;
    final p = (feature['properties'] as Map<String, dynamic>?) ?? const {};
    final name = (p['name'] as String?)?.trim() ?? '';
    final street = (p['street'] as String?)?.trim() ?? '';
    final houseNumber = (p['housenumber'] as String?)?.trim() ?? '';
    final city = (p['city'] as String?)?.trim() ?? '';
    final state = (p['state'] as String?)?.trim() ?? '';
    final postcode = (p['postcode'] as String?)?.trim() ?? '';

    final house = [houseNumber, street].where((s) => s.isNotEmpty).join(' ');
    final line = house.isNotEmpty ? house : (name.isNotEmpty ? name : null);
    final displayParts = <String>[
      if (name.isNotEmpty) name,
      if (house.isNotEmpty && house != name) house,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (postcode.isNotEmpty) postcode,
    ];
    return PhotonSuggestion(
      latitude: lat?.toDouble() ?? 0,
      longitude: lng?.toDouble() ?? 0,
      displayName: displayParts.join(', '),
      line: line,
      city: city.isNotEmpty ? city : null,
      state: state.isNotEmpty ? state : null,
      pin: postcode.isNotEmpty ? postcode : null,
    );
  }
}

/// Photon (OpenStreetMap) geocoder. Unauthenticated, free, fair-use.
/// OWNS the HTTP client so widget tests can inject a fake.
class PhotonClient {
  PhotonClient({http.Client? client, this.baseUrl = 'https://photon.komoot.io'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static PhotonClient? _singleton;

  /// App-wide instance. Tests use [newForTests] with a fake client.
  static PhotonClient get shared => _singleton ??= PhotonClient();

  @visibleForTesting
  static void injectForTests(PhotonClient client) {
    _singleton?._client.close();
    _singleton = client;
  }

  @visibleForTesting
  static PhotonClient newForTests(http.Client client) =>
      PhotonClient(client: client);

  void dispose() => _client.close();

  /// Search suggestions, India-bounded. Empty on any failure —
  /// callers show "no results", never an error page.
  Future<List<PhotonSuggestion>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    try {
      final uri = Uri.parse('$baseUrl/api/').replace(
        queryParameters: {
          'q': q,
          'limit': '$limit',
          'lang': 'en',
          // Bias to India — app is India-only.
          'bbox': '67.5,6.5,97.5,37.5',
        },
      );
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      return parseSearchBody(res.body);
    } catch (_) {
      return const [];
    }
  }

  /// Coordinates → readable address (Photon reverse).
  Future<PhotonSuggestion?> reverse(double latitude, double longitude) async {
    try {
      final uri = Uri.parse('$baseUrl/reverse').replace(
        queryParameters: {
          'lat': '$latitude',
          'lon': '$longitude',
          'lang': 'en',
        },
      );
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      return parseReverseBody(res.body);
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> get _headers => const {
    'User-Agent': 'oxro-app/1.0 (food-delivery)',
    'Accept': 'application/json',
  };

  /// Parses a Photon search response body (features[]).
  @visibleForTesting
  static List<PhotonSuggestion> parseSearchBody(String body) {
    try {
      final decoded = jsonDecode(body);
      final features = (decoded is Map ? decoded['features'] : null) as List?;
      if (features == null) return const [];
      return features
          .whereType<Map<String, dynamic>>()
          .map(PhotonSuggestion.fromFeature)
          .where((s) => s.latitude != 0 || s.longitude != 0)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Parses a Photon reverse response body (first feature, or null).
  @visibleForTesting
  static PhotonSuggestion? parseReverseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      final features = (decoded is Map ? decoded['features'] : null) as List?;
      if (features == null || features.isEmpty) return null;
      final first = features.first;
      if (first is! Map<String, dynamic>) return null;
      return PhotonSuggestion.fromFeature(first);
    } catch (_) {
      return null;
    }
  }
}
