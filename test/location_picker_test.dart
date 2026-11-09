import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/address/presentation/widgets/address_sheet.dart';
import 'package:oxro/features/location/data/photon_client.dart';
import 'package:oxro/features/location/presentation/screens/location_picker_screen.dart';

const _reverseResponse = '''
{
  "features": [
    {
      "geometry": {"type": "Point", "coordinates": [80.2707, 13.0827]},
      "properties": {
        "name": "Apollo Hospitals",
        "street": "Greams Road",
        "housenumber": "21",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "postcode": "600006"
      }
    }
  ]
}''';

const _searchResponse = '''
{
  "features": [
    {
      "geometry": {"type": "Point", "coordinates": [80.2341, 13.0604]},
      "properties": {
        "name": "Apollo Pharmacy",
        "street": "Nungambakkam High Road",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "postcode": "600034"
      }
    }
  ]
}''';

/// Fake Photon server — search and reverse routed by URL path.
class _FakePhoton extends http.BaseClient {
  int reverseCalls = 0;
  int searchCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final bool isReverse = path.endsWith('/reverse');
    final bool isSearch = path.endsWith('/api/') || path.endsWith('/api');
    if (isReverse) reverseCalls += 1;
    if (isSearch) searchCalls += 1;
    final body = isReverse
        ? _reverseResponse
        : isSearch
        ? _searchResponse
        : '{}';
    final status = (isReverse || isSearch) ? 200 : 404;
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.onPopped});
  final ValueChanged<LocationPick?> onPopped;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const ValueKey('open_picker'),
          onPressed: () async {
            onPopped(
              await Navigator.of(context).push<LocationPick>(
                MaterialPageRoute(builder: (_) => LocationPickerScreen()),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  late _FakePhoton fakePhoton;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AddressStore.resetForTests();
    LocationPickerScreen.gpsProbe = null;
    LocationPickerScreen.liveTiles = false;
    fakePhoton = _FakePhoton();
    PhotonClient.injectForTests(PhotonClient(client: fakePhoton));
  });

  tearDown(() {
    LocationPickerScreen.gpsProbe = null;
    LocationPickerScreen.liveTiles = true;
  });

  testWidgets('GPS fix is detected; coords shown; confirm pops the pick', (
    tester,
  ) async {
    LocationPickerScreen.gpsProbe = () async => const LatLng(13.0827, 80.2707);
    LocationPick? popped;
    await tester.pumpWidget(
      MaterialApp(home: _Harness(onPopped: (p) => popped = p)),
    );
    await tester.tap(find.byKey(const ValueKey('open_picker')));
    await tester.pumpAndSettle();
    // GPS + reverse geocoding (260 ms debounce) must both be done by now.
    expect(
      fakePhoton.reverseCalls,
      greaterThanOrEqualTo(1),
      reason: 'reverse geocode should run after the fix',
    );
    expect(find.byKey(const ValueKey('location_coords')), findsOneWidget);
    expect(find.textContaining('13.0827'), findsOneWidget);
    expect(find.textContaining('80.2707'), findsOneWidget);
    expect(find.byKey(const ValueKey('location_confirm')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('location_confirm')));
    await tester.pumpAndSettle();
    expect(popped, isNotNull);
    expect(popped!.latitude, closeTo(13.0827, 0.001));
    expect(popped!.longitude, closeTo(80.2707, 0.001));
    expect(popped!.city, 'Chennai');
    expect(popped!.pin, '600006');
    expect(popped!.line, contains('Greams Road'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GPS unavailable/denied shows retry and keeps confirm disabled', (
    tester,
  ) async {
    LocationPickerScreen.gpsProbe = () async => null;
    LocationPick? popped;
    await tester.pumpWidget(
      MaterialApp(home: _Harness(onPopped: (p) => popped = p)),
    );
    await tester.tap(find.byKey(const ValueKey('open_picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location_error')), findsOneWidget);
    expect(
      find.textContaining("Couldn't get your GPS location"),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('location_retry')), findsOneWidget);
    expect(popped, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retry re-detects GPS after a failure', (tester) async {
    var calls = 0;
    LocationPickerScreen.gpsProbe = () async {
      calls += 1;
      if (calls < 2) return null;
      return const LatLng(13.0827, 80.2707);
    };
    await tester.pumpWidget(MaterialApp(home: _Harness(onPopped: (_) {})));
    await tester.tap(find.byKey(const ValueKey('open_picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location_error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('location_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('location_error')), findsNothing);
    expect(find.textContaining('13.0827'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search suggestion moves the pin to the result', (tester) async {
    LocationPickerScreen.gpsProbe = () async => const LatLng(13.0827, 80.2707);
    LocationPick? popped;
    await tester.pumpWidget(
      MaterialApp(home: _Harness(onPopped: (p) => popped = p)),
    );
    await tester.tap(find.byKey(const ValueKey('open_picker')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('location_search')),
      'Apollo',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('location_results')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('location_result_0')));
    await tester.pumpAndSettle();
    expect(fakePhoton.searchCalls, greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('location_confirm')));
    await tester.pumpAndSettle();
    expect(popped, isNotNull);
    expect(popped!.latitude, closeTo(13.0604, 0.001));
    expect(popped!.longitude, closeTo(80.2341, 0.001));
    expect(popped!.pin, '600034');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Address sheet saves state, landmark and GPS coordinates', (
    tester,
  ) async {
    LocationPickerScreen.gpsProbe = () async => const LatLng(13.0827, 80.2707);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open_sheet'),
              onPressed: () => AddressSheet.open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open_sheet')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addr_pick_map')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('location_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('addr_coords')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('addr_name')),
      'Ravi Kumar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('addr_phone')),
      '9876543210',
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('addr_save')),
      find.byType(SingleChildScrollView),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('addr_save')));
    await tester.pumpAndSettle();

    final saved = AddressStore.instance.address;
    expect(saved, isNotNull);
    expect(saved!.line, contains('Greams Road'));
    expect(saved.city, 'Chennai');
    expect(saved.state, 'Tamil Nadu');
    expect(saved.pin, '600006');
    expect(saved.latitude, closeTo(13.0827, 0.001));
    expect(saved.longitude, closeTo(80.2707, 0.001));
    expect(saved.hasCoordinates, isTrue);
    expect(tester.takeException(), isNull);
  });
}
