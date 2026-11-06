import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/orders/data/order_store.dart';

const _p = Product(
  id: 903,
  name: 'Payment Curry',
  brand: 'OXRO',
  restaurantId: 'R-PAY',
  restaurantName: 'Pay Kitchen',
  price: 169,
  mrp: 199,
  rating: 4.3,
  reviews: 50,
  icon: Icons.restaurant,
  colors: [Colors.white],
);

const _addr = Address(
  id: 'home1',
  label: 'Home',
  name: 'Sachin V',
  phone: '9876543210',
  line: '123, Anna Nagar',
  city: 'Chennai',
  pin: '600040',
);

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() {
    CartStore.resetForTests();
    AddressStore.resetForTests();
    PaymentStore.resetForTests();
    OrderStore.resetForTests();
  });

  testWidgets('Payment Method row opens selection and updates checkout', (
    tester,
  ) async {
    CartStore.instance.add(_p);
    AddressStore.instance.save(_addr);
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await _frames(tester);

    // Bottom bar: Payment Method row + CHANGE + Place Order.
    expect(
      find.byKey(const ValueKey('checkout_pay_using_row')),
      findsOneWidget,
    );
    expect(find.text('Payment Method'), findsOneWidget);
    expect(find.text('CHANGE'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkout_place_order')), findsOneWidget);

    // Open the dedicated Select Payment Method screen.
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkout_pay_using_row')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('checkout_pay_using_row')));
    await _frames(tester);

    expect(find.text('Select Payment Method'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('UPI Payments'), findsOneWidget);
    expect(find.text('Google Pay (GPay)'), findsWidgets);
    expect(find.text('PhonePe'), findsWidgets);

    // Pick PhonePe (shown in Recommended + UPI Payments — tap the first).
    await tester.tap(find.text('PhonePe').first);
    await _frames(tester);
    expect(find.text('Selected'), findsOneWidget);

    // Reveal + assert each section below the fold (ListView is lazy).
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Cards'),
      300,
      scrollable: scrollable,
    );
    await _frames(tester, 2);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Add Credit Card'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Wallets'),
      300,
      scrollable: scrollable,
    );
    await _frames(tester, 2);
    expect(find.text('Wallets'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Other Payment Options'),
      300,
      scrollable: scrollable,
    );
    await _frames(tester, 2);
    expect(find.text('Other Payment Options'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Cash on Delivery'),
      300,
      scrollable: scrollable,
    );
    await _frames(tester, 2);
    expect(find.text('Cash on Delivery'), findsOneWidget);

    // Confirm → back to checkout with the new method on the row.
    await tester.tap(find.text('Confirm'));
    await _frames(tester);

    expect(find.text('Select Payment Method'), findsNothing);
    expect(PaymentStore.instance.paymentLabel, 'PhonePe');
    expect(find.textContaining('PhonePe'), findsOneWidget);
  });
}
