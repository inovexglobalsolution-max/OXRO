import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/location/data/geo_store.dart';
import 'package:oxro/features/location/presentation/screens/location_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void _noNetwork() {
  GeoStore.instance.injectClientForTests(
    MockClient((_) async => http.Response('offline', 404)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeoStore.resetForTests();
    AddressStore.resetForTests();
  });

  tearDown(() {
    GeoStore.resetForTests();
    AddressStore.resetForTests();
  });

  testWidgets('Location onboarding shows art and both actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LocationScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('location_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('location_city_art')), findsOneWidget);
    expect(find.byKey(const ValueKey('location_enable')), findsOneWidget);
    expect(find.byKey(const ValueKey('location_manual')), findsOneWidget);
    expect(find.text('Enable Device Location'), findsOneWidget);
    expect(find.text('Enter Your Location Manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Enable location continues after a successful GPS detect', (
    tester,
  ) async {
    GeoStore.gpsProbe = () async => const GeoPoint(13.08, 80.27);
    _noNetwork();

    await tester.pumpWidget(const MaterialApp(home: LocationScreen()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('location_enable')));
    await _settle(tester);

    expect(GeoStore.instance.place.source, GeoSource.gps);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Enable location stays put and explains the fallback', (
    tester,
  ) async {
    GeoStore.gpsProbe = () async => null;
    _noNetwork();

    await tester.pumpWidget(const MaterialApp(home: LocationScreen()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('location_enable')));
    await _settle(tester);

    expect(GeoStore.instance.place.source, GeoSource.fallback);
    expect(find.byKey(const ValueKey('location_screen')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      find.text(
        'Location unavailable. Allow device location or enter it manually.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Manual address saves and continues to login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LocationScreen()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('location_manual')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('addr_name')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('addr_name')),
      'Priya Raman',
    );
    await tester.enterText(
      find.byKey(const ValueKey('addr_phone')),
      '9876543210',
    );
    await tester.enterText(
      find.byKey(const ValueKey('addr_line')),
      '12 Anna Salai, Teynampet',
    );
    await tester.enterText(
      find.byKey(const ValueKey('addr_city')),
      'Chennai',
    );
    await tester.enterText(find.byKey(const ValueKey('addr_pin')), '600018');
    await tester.ensureVisible(find.byKey(const ValueKey('addr_save')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('addr_save')));
    await _settle(tester);

    expect(AddressStore.instance.hasValid, isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
