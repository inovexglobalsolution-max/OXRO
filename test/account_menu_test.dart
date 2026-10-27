import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/wishlist/data/wishlist_store.dart';

const _p = Product(
  id: 1001,
  name: 'Menu Tee',
  brand: 'OXRO',
  price: 499,
  mrp: 799,
  rating: 4.3,
  reviews: 120,
  icon: Icons.checkroom,
  colors: [Colors.white, Colors.black],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(Container());
}

Future<void> _goAccount(WidgetTester tester) async {
  CartStore.resetForTests();
  WishlistStore.resetForTests();
  AddressStore.resetForTests();
  await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('profile_btn')));
  await _settle(tester);
}

void main() {
  testWidgets('Profile shows Addresses/Help/Settings rows', (tester) async {
    await _goAccount(tester);
    final scroll = find.byKey(const ValueKey('profile_scroll'));

    // NOTE: grouped sections are taller — check each text right
    // after its own scroll so lazily-built rows are visible.
    final rows = {
      'profile_addresses': 'Addresses',
      'profile_help': 'Help & Support',
      'profile_settings': 'Settings',
    };
    for (final e in rows.entries) {
      await tester.dragUntilVisible(
        find.byKey(ValueKey(e.key)),
        scroll,
        const Offset(0, -300),
      );
      await _settle(tester);
      expect(find.byKey(ValueKey(e.key)), findsOneWidget);
      expect(find.text(e.value), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Addresses opens in manage mode (no checkout CTA)', (
    tester,
  ) async {
    await _goAccount(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_addresses')),
      find.byKey(const ValueKey('profile_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_addresses')));
    await _settle(tester);

    expect(find.text('My Addresses'), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('addr_add')), findsOneWidget);
    // Manage mode hides checkout continue.
    expect(find.byKey(const ValueKey('addr_continue')), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Help opens with FAQs + track order', (tester) async {
    await _goAccount(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_help')),
      find.byKey(const ValueKey('profile_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_help')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('help_scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('help_faq_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('help_track_order')), findsOneWidget);

    // Track order jumps back to Orders tab (OrdersScreen visible).
    await tester.tap(find.byKey(const ValueKey('help_track_order')));
    await _settle(tester);
    expect(find.text('My Addresses'), findsNothing);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('Settings toggles + clear works', (tester) async {
    CartStore.resetForTests();
    WishlistStore.resetForTests();
    CartStore.instance.add(_p);
    WishlistStore.instance.toggle(_p);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_btn')));
    await _settle(tester);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_settings')),
      find.byKey(const ValueKey('profile_scroll')),
      const Offset(0, -300),
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_settings')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('settings_scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_notifs')), findsOneWidget);

    final scrollable = find.byKey(const ValueKey('settings_scroll'));
    for (
      var i = 0;
      i < 4 &&
          tester.getCenter(find.byKey(const ValueKey('settings_clear'))).dy >
              540;
      i++
    ) {
      await tester.drag(scrollable, const Offset(0, -400));
      await _settle(tester);
    }
    await tester.tap(find.byKey(const ValueKey('settings_clear')));
    await _settle(tester);
    // Yes/No sheet first — data stays until Yes.
    expect(find.byKey(const ValueKey('clear_confirm_go')), findsOneWidget);
    expect(CartStore.instance.count, 1);
    await tester.tap(find.byKey(const ValueKey('clear_confirm_go')));
    await _settle(tester);
    expect(CartStore.instance.count, 0);
    expect(WishlistStore.instance.count, 0);
    expect(tester.takeException(), isNull);
    CartStore.resetForTests();
    WishlistStore.resetForTests();
    await _dispose(tester);
  });

  testWidgets('seller + admin rows are hidden, footer + back', (tester) async {
    await _goAccount(tester);
    final scroll = find.byKey(const ValueKey('profile_scroll'));

    // Seller/admin entry points are removed from the profile menu.
    expect(find.byKey(const ValueKey('profile_sell')), findsNothing);
    expect(find.byKey(const ValueKey('profile_seller_portal')), findsNothing);
    expect(find.byKey(const ValueKey('profile_admin')), findsNothing);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('profile_logout')),
      scroll,
      const Offset(0, -300),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('profile_logout')), findsOneWidget);
    expect(find.text('Seller Hub'), findsNothing);
    expect(find.text('Admin · Pricing'), findsNothing);
    await tester.fling(scroll, const Offset(0, -1200), 2500);
    await _settle(tester);
    expect(find.byKey(const ValueKey('profile_version')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Circular back button returns to the Delivery tab.
    await tester.fling(scroll, const Offset(0, 1600), 2500);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('profile_back')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('profile_back')), findsNothing);
    expect(find.byKey(const ValueKey('nav_delivery')), findsOneWidget);
    expect(find.byKey(const ValueKey('oxro_bottom_nav')), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Account menu 320 + 390 no overflow', (tester) async {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await _goAccount(tester);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('profile_help')),
        find.byKey(const ValueKey('profile_scroll')),
        const Offset(0, -300),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('profile_help')));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'help at $size');
      await _dispose(tester);

      await _goAccount(tester);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('profile_settings')),
        find.byKey(const ValueKey('profile_scroll')),
        const Offset(0, -300),
      );
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('profile_settings')));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'settings at $size');
      await _dispose(tester);
    }
  });
}
