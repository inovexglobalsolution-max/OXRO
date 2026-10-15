import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/applock/data/applock_store.dart';
import 'package:oxro/features/applock/presentation/screens/pin_screen.dart';
import 'package:oxro/features/applock/presentation/screens/set_pin_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/search/data/search_repo.dart';
import 'package:oxro/features/settings/data/storage_info.dart';
import 'package:oxro/features/settings/presentation/screens/settings_screen.dart';
import 'package:oxro/features/splash/presentation/screens/splash_screen.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _enterPin(WidgetTester tester, String pin,
    {bool set = false}) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.byKey(
        ValueKey(set ? 'pin_set_key_$ch' : 'pin_key_$ch')));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApplockStore.resetForTests();
  });

  test('hash stable + format gate', () {
    expect(ApplockStore.hashPin('1234'),
        ApplockStore.hashPin('1234'));
    expect(ApplockStore.hashPin('1234') == '1234', isFalse);
    expect(ApplockStore.validFormat('1234'), isTrue);
    expect(ApplockStore.validFormat('12'), isFalse);
    expect(ApplockStore.validFormat('abcd'), isFalse);
  });

  test('enable/verify/disable round-trip + persist', () async {
    expect(ApplockStore.instance.enabled, isFalse);
    expect(await ApplockStore.instance.enable('12', '12'), isFalse);
    expect(await ApplockStore.instance.enable('1234', '4321'),
        isFalse);
    expect(await ApplockStore.instance.enable('1234', '1234'),
        isTrue);
    expect(ApplockStore.instance.enabled, isTrue);
    expect(await ApplockStore.instance.verify('1234'), isTrue);
    expect(await ApplockStore.instance.verify('0000'), isFalse);

    // Simulate restart.
    ApplockStore.resetForTests();
    await ApplockStore.instance.load();
    expect(ApplockStore.instance.enabled, isTrue);
    expect(await ApplockStore.instance.verify('1234'), isTrue);

    await ApplockStore.instance.disable();
    expect(ApplockStore.instance.enabled, isFalse);
  });

  testWidgets('Set PIN mismatch restarts', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SetPinScreen()));
    await _settle(tester);

    await _enterPin(tester, '1234', set: true);
    await _settle(tester);
    await _enterPin(tester, '4321', set: true);
    await _settle(tester);
    expect(find.text('PINs do not match — try again'),
        findsOneWidget);
    expect(ApplockStore.instance.enabled, isFalse);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Set PIN match enables', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SetPinScreen()));
    await _settle(tester);

    await _enterPin(tester, '2468', set: true);
    await _settle(tester);
    await _enterPin(tester, '2468', set: true);
    await _settle(tester);
    expect(ApplockStore.instance.enabled, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
    ApplockStore.resetForTests();
  });

  testWidgets('Wrong PIN shakes, right PIN unlocks', (tester) async {
    await ApplockStore.instance.enable('1357', '1357');
    var unlocked = false;
    await tester.pumpWidget(MaterialApp(
        home: PinScreen(onUnlock: () => unlocked = true)));
    await _settle(tester);

    await _enterPin(tester, '0000');
    await _settle(tester);
    expect(unlocked, isFalse);
    expect(find.textContaining('Wrong PIN'), findsOneWidget);

    // Brute-force backoff: correct PIN inside the lockout is rejected.
    await _enterPin(tester, '1357');
    await _settle(tester);
    expect(unlocked, isFalse);

    // After the lockout clears, the right PIN unlocks.
    ApplockStore.clearLockoutForTests();
    await tester.pumpWidget(MaterialApp(
        home: PinScreen(onUnlock: () => unlocked = true)));
    await _settle(tester);
    await _enterPin(tester, '1357');
    await _settle(tester);
    expect(unlocked, isTrue);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
    ApplockStore.resetForTests();
  });

  testWidgets('Splash shows PIN gate when locked', (tester) async {
    SharedPreferences.setMockInitialValues({
      'oxro_lock_enabled': true,
      'oxro_lock_hash': ApplockStore.hashPin('9999'),
      'oxro_seen_onboarding': true,
    });
    ApplockStore.resetForTests();
    await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 2200));
    await _settle(tester);
    expect(find.text('Enter app PIN'), findsOneWidget);
    expect(find.byKey(const ValueKey('pin_dot_0')), findsOneWidget);
    expect(tester.takeException(), isNull);
    ApplockStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('Settings applock row present + storage card',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('settings_applock')),
      find.byKey(const ValueKey('settings_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('settings_applock')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('settings_storage')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('settings_clear_images')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('settings_clear_recents')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Clear searches wipes recents', (tester) async {
    SearchRepo.clearRecents();
    SearchRepo.pushRecent('nike');
    await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('settings_clear_recents')),
      find.byKey(const ValueKey('settings_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(
        find.byKey(const ValueKey('settings_clear_recents')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('clear_confirm_go')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('clear_confirm_go')));
    await _settle(tester);
    expect(SearchRepo.recents, isEmpty);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Clear cancel keeps data', (tester) async {
    CartStore.resetForTests();
    WishlistStore.resetForTests();
    CartStore.instance.add(const Product(
      id: 9001,
      name: 'Keep Me',
      brand: 'OXRO',
      price: 100,
      mrp: 200,
      rating: 4.0,
      reviews: 10,
      icon: Icons.star,
      colors: [Colors.white, Colors.black],
    ));
    await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('settings_clear')),
      find.byKey(const ValueKey('settings_scroll')),
      const Offset(0, -500),
    );
    await _settle(tester);
    await tester
        .tap(find.byKey(const ValueKey('settings_clear')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('clear_confirm_cancel')),
        findsOneWidget);
    await tester.tap(
        find.byKey(const ValueKey('clear_confirm_cancel')));
    await _settle(tester);
    expect(CartStore.instance.count, 1);
    expect(find.byKey(const ValueKey('clear_confirm_go')),
        findsNothing);
    expect(tester.takeException(), isNull);
    CartStore.resetForTests();
    WishlistStore.resetForTests();
    await _dispose(tester);
  });

  test('storage human + collect', () async {
    expect(StorageBreakdown.human(500), '500 B');
    expect(StorageBreakdown.human(2048), '2.0 KB');
    expect(StorageBreakdown.human(5 * 1024 * 1024), '5.0 MB');
    final b = await StorageInfo.collect();
    expect(b.totalBytes >= 0, isTrue);
    expect(b.fraction >= 0 && b.fraction <= 1, isTrue);
  });

  testWidgets('Settings 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
          const MaterialApp(home: SettingsScreen()));
      await _settle(tester);
      expect(tester.takeException(), isNull,
          reason: 'settings at $size');
      await _dispose(tester);
    }
  });
}
