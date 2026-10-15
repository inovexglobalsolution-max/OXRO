import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/location/presentation/screens/location_screen.dart';
import 'package:oxro/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:oxro/features/splash/presentation/screens/splash_screen.dart';

Future<void> _expectNoOverflow(
    WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump(const Duration(milliseconds: 800));
  // Repeat-frame animations keep ticking; drain one more frame then check.
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

void main() {
  const sizes = [
    Size(320, 568), // SE small
    Size(360, 640), // Moto
    Size(390, 844), // iPhone 14
    Size(412, 915), // Pixel
  ];

  for (final s in sizes) {
    testWidgets('Onboarding ${s.width}x${s.height} no overflow',
        (tester) async {
      await _expectNoOverflow(
          tester, s, const OnboardingScreen());
    });
    testWidgets('Location ${s.width}x${s.height} no overflow',
        (tester) async {
      await _expectNoOverflow(tester, s, const LocationScreen());
    });
  }

  testWidgets('Splash 320x568 no overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    ProfileStore.resetForTests();
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    // Let splash boot (prefs load + brand delay) fire navigation.
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Skip >'), findsOneWidget);
    ProfileStore.resetForTests();
  });
}
