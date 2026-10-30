import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/auth/presentation/screens/login_screen.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';
import 'package:oxro/features/notifications/presentation/screens/notification_permission_screen.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

void main() {
  setUp(() => NotifStore.resetForTests());

  testWidgets('Permission page shows title, subtitle and both actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationPermissionScreen()),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('notif_perm_screen')), findsOneWidget);
    expect(find.text('Get updates on your order status'), findsOneWidget);
    expect(
      find.text(
        'Allow push notifications to get real-time updates '
        'on your order status.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('notif_perm_enable')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif_perm_skip')), findsOneWidget);
    expect(find.text('Turn on Notification'), findsOneWidget);
    expect(find.text('Not Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Turn on Notification enables store and opens login', (
    tester,
  ) async {
    NotifStore.instance.setEnabled(false);
    await tester.pumpWidget(
      const MaterialApp(home: NotificationPermissionScreen()),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('notif_perm_enable')));
    await _settle(tester);

    expect(NotifStore.instance.enabled, isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Not Now disables store and opens login', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotificationPermissionScreen()),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('notif_perm_skip')));
    await _settle(tester);

    expect(NotifStore.instance.enabled, isFalse);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
