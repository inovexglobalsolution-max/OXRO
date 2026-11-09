import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/location/data/photon_client.dart';

const _searchBody = '''
{
  "features": [
    {
      "geometry": {"type": "Point", "coordinates": [80.2707, 13.0827]},
      "properties": {
        "name": "Apollo Hospitals",
        "housenumber": "21",
        "street": "Greams Road",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "postcode": "600006"
      }
    },
    {
      "geometry": {"type": "Point", "coordinates": [80.2341, 13.0604]},
      "properties": {
        "name": "Apollo Pharmacy",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "postcode": "600034"
      }
    }
  ]
}''';

const _reverseBody = '''
{
  "features": [
    {
      "geometry": {"type": "Point", "coordinates": [77.5946, 12.9716]},
      "properties": {
        "street": "MG Road",
        "housenumber": "10",
        "city": "Bengaluru",
        "state": "Karnataka",
        "postcode": "560001"
      }
    }
  ]
}''';

void main() {
  test('search parses coordinates as [lng, lat] (Photon order)', () {
    final results = PhotonClient.parseSearchBody(_searchBody);
    expect(results, hasLength(2));
    expect(results[0].latitude, closeTo(13.0827, 1e-6));
    expect(results[0].longitude, closeTo(80.2707, 1e-6));
    expect(results[0].displayName, contains('Apollo Hospitals'));
    expect(results[0].displayName, contains('Chennai'));
    expect(results[0].displayName, contains('600006'));
    expect(results[0].line, '21 Greams Road');
    expect(results[0].city, 'Chennai');
    expect(results[0].state, 'Tamil Nadu');
    expect(results[0].pin, '600006');
    // Second hit has no street — falls back to the plain name as the line.
    expect(results[1].line, 'Apollo Pharmacy');
  });

  test('search returns empty on malformed payloads — never throws', () {
    expect(PhotonClient.parseSearchBody('not json'), isEmpty);
    expect(PhotonClient.parseSearchBody('{"features": "oops"}'), isEmpty);
    expect(PhotonClient.parseSearchBody('{}'), isEmpty);
  });

  test('reverse parses first feature', () {
    final place = PhotonClient.parseReverseBody(_reverseBody);
    expect(place, isNotNull);
    expect(place!.latitude, closeTo(12.9716, 1e-6));
    expect(place.longitude, closeTo(77.5946, 1e-6));
    expect(place.line, '10 MG Road');
    expect(place.city, 'Bengaluru');
  });

  test('reverse returns null on empty/missing features', () {
    expect(PhotonClient.parseReverseBody('{"features": []}'), isNull);
    expect(PhotonClient.parseReverseBody('garbage'), isNull);
  });
}
