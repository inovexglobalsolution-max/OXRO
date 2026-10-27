import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileStore.resetForTests();
  });

  testWidgets('welcome popup appears once and auto-dismisses', (tester) async {
    await ProfileStore.instance.save(email: 'priya@oxro.in', name: 'Priya');

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('welcome_popup')), findsOneWidget);
    expect(find.text('Welcome to OXRO 🛍️'), findsOneWidget);
    expect(find.text('Your Shopping Journey Starts Here!'), findsOneWidget);

    // Still readable after 3 seconds.
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('welcome_popup')), findsOneWidget);

    // Auto-dismissed by ~6 seconds (pump frames like a real display).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump();

    expect(find.byKey(const ValueKey('welcome_popup')), findsNothing);
    expect(ProfileStore.instance.welcomeShown, isTrue);

    await tester.pumpWidget(Container());
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.byKey(const ValueKey('welcome_popup')), findsNothing);
    await tester.pumpWidget(Container());
  });
}
