import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:oxro/app/routing/polyline.dart';

/// Driving route between two points.
///
/// Uses Google Directions when `DIRECTIONS_API_KEY` is provided at build time,
/// otherwise falls back to the public OSRM router. Never fabricates a route —
/// on failure it returns null and callers draw a straight line or hide the
/// polyline caption.
class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
}

class DirectionsClient {
  DirectionsClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _directionsKey = String.fromEnvironment(
    'DIRECTIONS_API_KEY',
  );

  @visibleForTesting
  Future<RouteResult?> Function(LatLng origin, LatLng destination)?
  debugRouteOverride;

  Future<RouteResult?> route(LatLng origin, LatLng destination) async {
    final override = debugRouteOverride;
    if (override != null) return override(origin, destination);

    if (_directionsKey.isNotEmpty) {
      final google = await _fromGoogle(origin, destination);
      if (google != null) return google;
    }
    return _fromOsrm(origin, destination);
  }

  Future<RouteResult?> _fromGoogle(LatLng origin, LatLng destination) async {
    try {
      final uri =
          Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json',
          ).replace(
            queryParameters: {
              'origin': '${origin.latitude},${origin.longitude}',
              'destination': '${destination.latitude},${destination.longitude}',
              'mode': 'driving',
              'key': _directionsKey,
            },
          );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return null;
      final routes = body['routes'] as List;
      if (routes.isEmpty) return null;
      final legs = routes.first['legs'] as List;
      if (legs.isEmpty) return null;
      final distance = (legs.first['distance']['value'] as num).toDouble();
      final duration = (legs.first['duration']['value'] as num).toInt();
      final points = decodePolyline(
        routes.first['overview_polyline']['points'] as String,
      );
      if (points.length < 2) return null;
      return RouteResult(
        points: points,
        distanceKm: distance / 1000.0,
        durationMinutes: (duration / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<RouteResult?> _fromOsrm(LatLng origin, LatLng destination) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final routes = body['routes'] as List;
      if (routes.isEmpty) return null;
      final geometry = routes.first['geometry'] as String?;
      if (geometry == null) return null;
      final points = decodePolyline(geometry);
      if (points.length < 2) return null;
      final distance = (routes.first['distance'] as num).toDouble();
      final duration = (routes.first['duration'] as num).toInt();
      return RouteResult(
        points: points,
        distanceKm: distance / 1000.0,
        durationMinutes: (duration / 60).round(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Straight-line distance in km between two coordinates.
double haversineKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  double toRad(double deg) => deg * math.pi / 180.0;
  final dLat = toRad(b.latitude - a.latitude);
  final dLng = toRad(b.longitude - a.longitude);
  final sinHalfLat = math.sin(dLat / 2);
  final sinHalfLng = math.sin(dLng / 2);
  final h =
      sinHalfLat * sinHalfLat +
      math.cos(toRad(a.latitude)) *
          math.cos(toRad(b.latitude)) *
          sinHalfLng *
          sinHalfLng;
  return 2 * earthRadiusKm * math.asin(math.sqrt(h));
}
