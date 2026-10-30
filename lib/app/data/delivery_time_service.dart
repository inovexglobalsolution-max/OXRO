import 'package:oxro/features/cart/data/cart_store.dart';
import 'package:oxro/features/restaurants/data/restaurant.dart';

/// A reusable, configurable estimator for the complete order's delivery time.
///
/// This is an ESTIMATE, not a real-time or guaranteed delivery promise.
/// It combines configurable kitchen/dispatch assumptions with the restaurant's
/// published delivery travel time. Nothing here claims backend-backed accuracy.
class DeliveryTimeService {
  /// Configurable assumptions (minutes). These are example defaults only —
  /// swap in real business rules when the backend provides them.
  const DeliveryTimeService({
    this.basePrepMinutes = 10,
    this.perDishWorkloadMinutes = 3,
    this.perExtraQuantityMinutes = 1,
    this.packagingDispatchMinutes = 5,
  });

  /// One-time kitchen prep before any dish is cooked.
  final int basePrepMinutes;

  /// Per distinct-dish setup workload (different dishes may prep in parallel,
  /// so this is summed over distinct dishes, not multiplied by total quantity).
  final int perDishWorkloadMinutes;

  /// Per extra unit of the same dish beyond the first (units of one dish prep
  /// together, so duplicates add less than a full dish).
  final int perExtraQuantityMinutes;

  /// Packaging and hand-off to the delivery partner.
  final int packagingDispatchMinutes;

  /// Estimate for the whole cart at [restaurant].
  ///
  /// Returns [low]/[high] minutes plus human-readable [assumptions].
  /// Returns `null` when the cart is empty or no restaurant is known.
  DeliveryTimeEstimate? estimateForCart({
    required List<CartLine> lines,
    required Restaurant? restaurant,
  }) {
    if (lines.isEmpty || restaurant == null) return null;

    int workload = 0;
    for (final l in lines) {
      workload +=
          perDishWorkloadMinutes + perExtraQuantityMinutes * (l.qty - 1);
    }
    // Cap workload so a huge bag does not balloon the estimate unrealistically.
    workload = workload.clamp(0, 60);

    final kitchenMinutes =
        basePrepMinutes + workload + packagingDispatchMinutes;
    final travelMinutes = restaurant.etaMinutes;

    final low = kitchenMinutes + travelMinutes;
    final high = low + (travelMinutes ~/ 2).clamp(5, 15);

    return DeliveryTimeEstimate(
      low: low,
      high: high,
      assumptions: [
        'Base kitchen prep: $basePrepMinutes min',
        'Order workload: +$workload min (complete order)',
        'Packaging & dispatch: +$packagingDispatchMinutes min',
        'Delivery travel: $travelMinutes min (restaurant estimate)',
      ],
    );
  }
}

class DeliveryTimeEstimate {
  const DeliveryTimeEstimate({
    required this.low,
    required this.high,
    required this.assumptions,
  });

  final int low;
  final int high;
  final List<String> assumptions;

  String get rangeLabel => '$low–$high min';
  bool get isRange => low != high;
}
