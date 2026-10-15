import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/splash/presentation/screens/splash_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.resetForTests();
  });

  test('save/load/logout round-trip', () async {
    expect(ProfileStore.instance.isLoggedIn, isFalse);
    expect(ProfileStore.instance.displayName, 'Guest User');

    await ProfileStore.instance
        .save(email: 'priya@oxro.in', name: 'Priya');
    expect(ProfileStore.instance.isLoggedIn, isTrue);
    expect(ProfileStore.instance.displayName, 'Priya');

    // Simulate restart: wipe memory, reload from prefs.
    ProfileStore.resetForTests();
    await ProfileStore.instance.load();
    expect(ProfileStore.instance.isLoggedIn, isTrue);
    expect(ProfileStore.instance.displayName, 'Priya');
    expect(ProfileStore.instance.email, 'priya@oxro.in');

    await ProfileStore.instance.logout();
    expect(ProfileStore.instance.isLoggedIn, isFalse);
    ProfileStore.resetForTests();
    await ProfileStore.instance.load();
    expect(ProfileStore.instance.isLoggedIn, isFalse);
  });

  test('updateName validates', () async {
    await ProfileStore.instance
        .save(email: 'a@b.co', name: 'Abc Def');
    expect(await ProfileStore.instance.updateName('x'), isFalse);
    expect(await ProfileStore.instance.updateName('Ravi Kumar'),
        isTrue);
    expect(ProfileStore.instance.displayName, 'Ravi Kumar');
  });

  test('phone validates + persists', () async {
    expect(ProfileStore.validatePhone(''), isNull);
    expect(ProfileStore.validatePhone('123'), isNotNull);
    expect(ProfileStore.validatePhone('9876543210'), isNull);
    expect(ProfileStore.validatePhone('1234567890'), isNotNull);

    await ProfileStore.instance.save(email: 'a@b.co', name: 'Abc');
    expect(await ProfileStore.instance.updatePhone('123'), isFalse);
    expect(await ProfileStore.instance.updatePhone('9876543210'),
        isTrue);
    expect(ProfileStore.instance.phone, '9876543210');

    // Restart persists phone.
    ProfileStore.resetForTests();
    await ProfileStore.instance.load();
    expect(ProfileStore.instance.phone, '9876543210');

    // Empty clears.
    expect(await ProfileStore.instance.updatePhone(''), isTrue);
    expect(ProfileStore.instance.phone, isNull);
  });

  test('onboarding flag persists, logout keeps it', () async {
    await ProfileStore.instance.markOnboardingSeen();
    expect(ProfileStore.instance.seenOnboarding, isTrue);
    await ProfileStore.instance
        .save(email: 'a@b.co', name: 'Abc');
    await ProfileStore.instance.logout();
    expect(ProfileStore.instance.seenOnboarding, isTrue);
    ProfileStore.resetForTests();
    await ProfileStore.instance.load();
    expect(ProfileStore.instance.seenOnboarding, isTrue);
    expect(ProfileStore.instance.isLoggedIn, isFalse);
  });

  testWidgets('Splash skips to Home when logged in', (tester) async {
    SharedPreferences.setMockInitialValues({
      'oxro_email': 'priya@oxro.in',
      'oxro_name': 'Priya',
      'oxro_seen_onboarding': true,
    });
    ProfileStore.resetForTests();
    await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 2200));
    await _settle(tester);
    expect(find.text('Shop by Category'), findsOneWidget);
    expect(tester.takeException(), isNull);
    ProfileStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Splash goes to Login when seen but logged out',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'oxro_seen_onboarding': true,
    });
    ProfileStore.resetForTests();
    await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 2200));
    await _settle(tester);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
    ProfileStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Edit screen saves name', (tester) async {
    await ProfileStore.instance
        .save(email: 'a@b.co', name: 'Old Name');
    await tester.pumpWidget(
        const MaterialApp(home: EditProfileScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('edit_name')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('edit_name')), 'x');
    await tester.tap(find.byKey(const ValueKey('edit_save')));
    await _settle(tester);
    expect(find.text('Enter a valid name (min 3 letters)'),
        findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('edit_name')), 'New Name');
    await tester.tap(find.byKey(const ValueKey('edit_save')));
    await _settle(tester);
    expect(ProfileStore.instance.displayName, 'New Name');
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Account shows saved name + edit opens', (tester) async {
    await ProfileStore.instance
        .save(email: 'priya@oxro.in', name: 'Priya');
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.tap(find.text('Account'));
    await _settle(tester);
    expect(find.text('Priya'), findsOneWidget);
    expect(find.text('priya@oxro.in'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_edit')),
      find.byKey(const ValueKey('profile_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_edit')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('edit_scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    ProfileStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Edit saves phone + rejects bad phone', (tester) async {
    await ProfileStore.instance
        .save(email: 'a@b.co', name: 'Old Name');
    await tester.pumpWidget(
        const MaterialApp(home: EditProfileScreen()));
    await _settle(tester);

    expect(find.byKey(const ValueKey('edit_phone')), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('edit_name')), 'New Name');
    await tester.enterText(
        find.byKey(const ValueKey('edit_phone')), '123');
    await tester.tap(find.byKey(const ValueKey('edit_save')));
    await _settle(tester);
    expect(find.text('Enter valid 10-digit mobile'), findsOneWidget);
    expect(ProfileStore.instance.phone, isNull);

    await tester.enterText(
        find.byKey(const ValueKey('edit_phone')), '9876543210');
    await tester.tap(find.byKey(const ValueKey('edit_save')));
    await _settle(tester);
    // Saved state shows before auto-pop.
    expect(ProfileStore.instance.phone, '9876543210');
    expect(ProfileStore.instance.displayName, 'New Name');
    expect(tester.takeException(), isNull);
    ProfileStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Edit 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
          const MaterialApp(home: EditProfileScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'edit at $size');
      await _dispose(tester);
    }
  });
}
