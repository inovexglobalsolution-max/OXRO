import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/bag/presentation/screens/bag_screen.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/help/data/support_store.dart';
import 'package:oxro/features/help/presentation/screens/help_screen.dart';
import 'package:oxro/features/help/presentation/screens/support_request_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';

const _food = Product(
  id: 78001,
  name: 'Paneer Bowl',
  brand: 'Green Bowl',
  restaurantId: 'R-FOOD',
  restaurantName: 'Green Bowl',
  price: 249,
  mrp: 299,
  rating: 4.3,
  reviews: 120,
  icon: Icons.rice_bowl,
  colors: [Colors.white, Colors.green],
);

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
    CartStore.resetForTests();
    OrderStore.resetForTests();
    SupportStore.resetForTests();
  });

  test('Support store keeps tickets and filters by order', () {
    final orderTicket = SupportStore.instance.submit(
      source: SupportSource.order,
      categoryId: 'missing_item',
      categoryLabel: 'Item missing',
      orderId: 'OXRO123456',
      restaurantName: "Domino's",
      items: const ['Peppy Paneer'],
      note: 'One item was missing',
    );
    final bagTicket = SupportStore.instance.submit(
      source: SupportSource.bag,
      categoryId: 'price_coupon',
      categoryLabel: 'Price / coupon issue',
      restaurantName: 'Green Bowl',
    );

    expect(SupportStore.instance.recent.first.id, bagTicket.id);
    expect(
      SupportStore.instance.forOrder('OXRO123456').single.id,
      orderTicket.id,
    );
    expect(orderTicket.items, ['Peppy Paneer']);
    expect(orderTicket.status, 'Submitted');
  });

  testWidgets('Bag Help opens and submits a pre-order request', (tester) async {
    CartStore.instance.add(_food);
    await tester.pumpWidget(MaterialApp(home: BagScreen(onShopNow: () {})));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('bag_help')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('help_bag_context')), findsOneWidget);
    expect(find.text('Green Bowl'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('help_bag_report')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('issue_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('issue_context')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('issue_category_price_coupon')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('issue_submit')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('issue_success')), findsOneWidget);
    expect(find.byKey(const ValueKey('issue_ticket')), findsOneWidget);
    final ticket = SupportStore.instance.recent.single;
    expect(ticket.source, SupportSource.bag);
    expect(ticket.restaurantName, 'Green Bowl');
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Order Details Help uses order context and missing item flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: OrderDetailsScreen(orderId: 'OXRO123456')),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('details_return')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('help_order_context')), findsOneWidget);
    expect(find.text('Order OXRO123456'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('help_report_issue')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('issue_screen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('issue_category_missing_item')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('issue_category_missing_item')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('issue_submit')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('issue_success')), findsNothing);

    final item = find.byKey(const ValueKey('issue_item_0'));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('issue_submit')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('issue_success')), findsOneWidget);
    final ticket = SupportStore.instance.recent.single;
    expect(ticket.source, SupportSource.order);
    expect(ticket.orderId, 'OXRO123456');
    expect(ticket.categoryId, 'missing_item');
    expect(ticket.items, isNotEmpty);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Help reports an issue against a chosen order', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HelpScreen(onOrders: () {})));
    await _settle(tester);

    expect(find.byKey(const ValueKey('help_faq_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('help_track_order')), findsOneWidget);
    expect(find.text('1800-123-456 (toll-free)'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('help_report_issue')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('help_order_picker')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('help_pick_order_OXRO123457')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('issue_screen')), findsOneWidget);
    expect(find.text('Order OXRO123457'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('issue_category_delayed')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Issue categories follow order status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SupportRequestScreen(
          key: ValueKey('active'),
          orderId: 'OXRO123457',
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('issue_category_delayed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('issue_category_missing_item')),
      findsNothing,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SupportRequestScreen(
          key: ValueKey('delivered'),
          orderId: 'OXRO123456',
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('issue_category_missing_item')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('issue_category_delayed')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Help and issue flow fit a 320px phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SupportRequestScreen(orderId: 'OXRO123456')),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _dispose(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: HelpScreen(
          onOrders: null,
          bagContext: true,
          restaurantName: 'Green Bowl',
        ),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('help_bag_context')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
