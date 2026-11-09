import 'package:latlong2/latlong.dart';

/// Google encoded-polyline decoder.
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
List<LatLng> decodePolyline(String encoded) {
  final result = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var value = 0;
    int b;
    do {
      if (index >= encoded.length) return result;
      b = encoded.codeUnitAt(index) - 63;
      index++;
      value |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLat = (value & 1) != 0 ? ~(value >> 1) : (value >> 1);
    lat += dLat;

    shift = 0;
    value = 0;
    do {
      if (index >= encoded.length) return result;
      b = encoded.codeUnitAt(index) - 63;
      index++;
      value |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLng = (value & 1) != 0 ? ~(value >> 1) : (value >> 1);
    lng += dLng;

    result.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return result;
}
