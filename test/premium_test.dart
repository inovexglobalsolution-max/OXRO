import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/premium/data/premium_store.dart';
import 'package:oxro/features/premium/presentation/screens/premium_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void _phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PremiumStore.resetForTests();
  });

  tearDown(PremiumStore.resetForTests);

  test('Premium store joins, persists and cancels', () async {
    final store = PremiumStore.instance;
    expect(store.isMember, isFalse);
    expect(store.joinedAt, isNull);

    store.join();
    expect(store.isMember, isTrue);
    expect(store.joinedAt, isNotNull);

    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('oxro_premium_v1'), isNotNull);

    PremiumStore.resetForTests();
    expect(store.isMember, isFalse);
    await store.load();
    expect(store.isMember, isTrue);
    expect(store.joinedAt, isNotNull);

    store.cancel();
    expect(store.isMember, isFalse);
    expect(store.joinedAt, isNull);
  });

  testWidgets('PREMIUM banner CTA opens the membership screen', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.drag(
      find.byKey(const ValueKey('food_banner_carousel')),
      const Offset(-390, 0),
    );
    await _settle(tester);

    expect(find.text('OXRO PREMIUM'), findsWidgets);
    expect(find.text('FREE DELIVERY'), findsWidgets);

    final cta = find.byKey(const ValueKey('banner_cta_1'));
    expect(cta, findsOneWidget);
    await tester.tap(cta);
    await _settle(tester);

    expect(find.byKey(const ValueKey('premium_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('premium_join')), findsOneWidget);
    expect(find.text('WHAT YOU GET'), findsOneWidget);
    expect(find.text('3 months at ₹1'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('premium_join')));
    await _settle(tester);

    expect(PremiumStore.instance.isMember, isTrue);
    expect(find.byKey(const ValueKey('premium_manage')), findsOneWidget);
    expect(find.text("You're a PREMIUM member"), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('premium_back')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('premium_screen')), findsNothing);
    expect(find.text('Manage'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PREMIUM screen fits a small phone and a tablet', (tester) async {
    for (final size in const [Size(320, 640), Size(768, 1024)]) {
      _phone(tester, size);
      await tester.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await _settle(tester);

      expect(find.byKey(const ValueKey('premium_screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('premium_join')), findsOneWidget);
      expect(find.text('Join PREMIUM at ₹1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _dispose(tester);
    }
  });
}
