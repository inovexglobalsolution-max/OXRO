import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/app/widgets/product_share.dart';
import 'package:oxro/app/widgets/restaurant_card.dart';
import 'package:oxro/features/detail/presentation/screens/product_detail_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';
import 'package:oxro/features/listing/presentation/screens/product_listing_screen.dart';
import 'package:oxro/features/reviews/data/review_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _p = Product(
  id: 777001,
  name: 'Share Test Kurta',
  brand: 'OXRO Select',
  price: 1499,
  mrp: 2999,
  rating: 4.3,
  reviews: 321,
  icon: Icons.checkroom_outlined,
  colors: [Color(0xFFFFE3CB), Color(0xFFFFC79B)],
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
    ReviewStore.resetForTests();
  });

  test('share text carries brand, name, price, off + link', () {
    final t = shareTextFor(_p);
    expect(t, contains('OXRO Select'));
    expect(t, contains('Share Test Kurta'));
    expect(t, contains('₹1,499'));
    expect(t, contains('50% off'));
    expect(t, contains('https://oxro.in/p/777001'));
  });

  testWidgets('Home restaurant feed renders cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await _settle(tester);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('food_restaurants_header')),
      find.byKey(const ValueKey('home_scroll')),
      const Offset(0, -400),
    );
    await _settle(tester);
    expect(find.byType(RestaurantCard), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PLP cards show share buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProductListingScreen(title: 'T', leafs: ['Kurtas']),
      ),
    );
    await _settle(tester);

    expect(find.byType(ProductShareButton), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('PDP gallery + similars show share buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductDetailScreen(product: _p)),
    );
    await _settle(tester);

    expect(find.byKey(ValueKey('share_${_p.id}')), findsWidgets);
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
