import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxro/features/address/data/address_store.dart';
import 'package:oxro/features/checkout/data/payment_store.dart';
import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/orders/data/order_store.dart';
import 'package:oxro/app/repositories/order_repo.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OrderStore.resetForTests();
    AddressStore.resetForTests();
    CartStore.resetForTests();
    PaymentStore.resetForTests();
    TrackingScreen.debugTrackingOverride = null;
  });

  tearDown(() {
    TrackingScreen.debugTrackingOverride = null;
  });

  testWidgets(
    'premium tracking renders partner card, progress tracker and address',
    (tester) async {
      TrackingScreen.debugTrackingOverride = const LiveTracking(
        status: 'outForDelivery',
        estimatedArrivalMinutes: 12,
        etaLabel: 'On the way',
        partnerName: 'Rahul Kumar',
        partnerPhone: '9876543210',
        partnerRating: 4.8,
        partnerCompletedDeliveries: 1243,
        partnerVehicleType: 'Motorcycle',
        partnerVehicleNumber: 'TN 09 AB 1234',
        partnerVerified: true,
        partnerLat: 13.05,
        partnerLng: 80.25,
        customerLat: 13.0827,
        customerLng: 80.2707,
        deliveryInstructions: 'Leave at the door',
        restaurantId: 'r_paradise',
        restaurantName: 'Paradise Biryani',
      );

      await tester.pumpWidget(
        const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('track_map_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('track_partner_card')), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Phone not available'), findsNothing);
      expect(find.byKey(const ValueKey('track_progress')), findsOneWidget);
      expect(find.byKey(const ValueKey('track_address')), findsOneWidget);
      expect(find.byKey(const ValueKey('track_restaurant')), findsOneWidget);
      expect(find.byKey(const ValueKey('track_partner_call')), findsOneWidget);
      expect(find.byKey(const ValueKey('track_partner_chat')), findsOneWidget);
      expect(find.byKey(const ValueKey('track_help_support')), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delivery instructions card shows the saved instruction', (
    tester,
  ) async {
    TrackingScreen.debugTrackingOverride = const LiveTracking(
      status: 'shipped',
      estimatedArrivalMinutes: 20,
      partnerName: 'Rahul Kumar',
      partnerPhone: '9876543210',
      partnerLat: 13.05,
      partnerLng: 80.25,
      customerLat: 13.0827,
      customerLng: 80.2707,
      deliveryInstructions: 'Leave at the door please',
      restaurantId: 'r_paradise',
      restaurantName: 'Paradise Biryani',
    );

    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('track_instructions_preview')),
      findsOneWidget,
    );
    expect(find.text('Leave at the door please'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('track_instructions_toggle')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable live tracking renders graceful fallback', (
    tester,
  ) async {
    TrackingScreen.debugTrackingOverride = null;

    await tester.pumpWidget(
      const MaterialApp(home: TrackingScreen(orderId: 'OXRO123457')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('track_partner_pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('track_map_unavailable')), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
