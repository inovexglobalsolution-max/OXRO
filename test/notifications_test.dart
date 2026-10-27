import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/notifications/data/notification_store.dart';
import 'package:oxro/features/notifications/presentation/screens/notifications_screen.dart';

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

  test('unread/markRead/markAllRead', () {
    expect(NotifStore.instance.unreadCount, 6);
    NotifStore.instance.markRead('n1');
    expect(NotifStore.instance.unreadCount, 5);
    NotifStore.instance.markAllRead();
    expect(NotifStore.instance.unreadCount, 0);
  });

  test('toggleRead/remove/restoreLast', () {
    expect(NotifStore.instance.items.length, 6);
    NotifStore.instance.toggleRead('n1');
    expect(NotifStore.instance.unreadCount, 5);
    NotifStore.instance.toggleRead('n1');
    expect(NotifStore.instance.unreadCount, 6);
    expect(NotifStore.instance.remove('n2'), isTrue);
    expect(NotifStore.instance.items.length, 5);
    expect(NotifStore.instance.restoreLast(), isTrue);
    expect(NotifStore.instance.items.length, 6);
    expect(NotifStore.instance.restoreLast(), isFalse);
  });

  testWidgets('Account menu opens inbox', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    // Bell removed from header — entry now lives in Account tab.
    expect(find.byKey(const ValueKey('notif_bell')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    final notifFinder =
        find.byKey(const ValueKey('profile_notifications'));
    expect(notifFinder, findsOneWidget);
    await tester.scrollUntilVisible(notifFinder, 300);
    await _settle(tester);
    await tester.tap(notifFinder, warnIfMissed: false);
    await _settle(tester);
    expect(find.byKey(const ValueKey('notif_scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif_row_n1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Filter chips + order tap goes to Orders', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NotificationsScreen(onOrders: () {}, onOffer: () {}),
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('notif_chip_orders')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('notif_row_n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif_row_n3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notif_chip_offers')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('notif_row_n3')), findsOneWidget);
    expect(find.byKey(const ValueKey('notif_row_n1')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Notifications 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      NotifStore.resetForTests();
      await tester.pumpWidget(MaterialApp(
        home: NotificationsScreen(onOrders: () {}, onOffer: () {}),
      ));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'notif at $size');
      await _dispose(tester);
    }
  });
}
