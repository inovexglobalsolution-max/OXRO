import 'money.dart';
import 'pricing_config.dart';

/// One restaurant's share of a cart.
class SubOrderInput {
  const SubOrderInput({
    required this.restaurantId,
    required this.foodSubtotalPaise,
    this.packagingPaise = 0,
    this.deliveryFeePaise = 0,
    this.restaurantDiscountPaise = 0,
    this.oxroDiscountPaise = 0,
    this.tipPaise = 0,
    this.commissionBpsOverride,
  });

  final String restaurantId;

  /// Sum of dish prices before any discount.
  final int foodSubtotalPaise;
  final int packagingPaise;
  final int deliveryFeePaise;

  /// Discount funded by the restaurant (reduces commission base).
  final int restaurantDiscountPaise;

  /// Discount funded by OXRO (does *not* reduce seller settlement).
  final int oxroDiscountPaise;
  final int tipPaise;

  /// Per-restaurant commission override; null = use config.
  final int? commissionBpsOverride;

  Map<String, dynamic> toJson() => {
        'restaurantId': restaurantId,
        'foodSubtotalPaise': foodSubtotalPaise,
        'packagingPaise': packagingPaise,
        'deliveryFeePaise': deliveryFeePaise,
        'restaurantDiscountPaise': restaurantDiscountPaise,
        'oxroDiscountPaise': oxroDiscountPaise,
        'tipPaise': tipPaise,
        if (commissionBpsOverride != null)
          'commissionBpsOverride': commissionBpsOverride,
      };
}

/// Customer-facing order being priced.
class OrderQuoteInput {
  const OrderQuoteInput({
    required this.subOrders,
    this.platformFeeOverridePaise,
  });

  final List<SubOrderInput> subOrders;

  /// Admin promo can force the platform fee to ₹0 (or any value).
  final int? platformFeeOverridePaise;
}

/// Seller settlement for one restaurant.
class SubOrderQuote {
  const SubOrderQuote({
    required this.restaurantId,
    required this.foodSubtotalPaise,
    required this.restaurantDiscountPaise,
    required this.commissionBasePaise,
    required this.commissionBps,
    required this.commissionPaise,
    required this.commissionGstPaise,
    required this.tdsPaise,
    required this.settlementPaise,
    required this.packagingPaise,
    required this.deliveryFeePaise,
    required this.oxroDiscountPaise,
    required this.tipPaise,
  });

  final String restaurantId;
  final int foodSubtotalPaise;
  final int restaurantDiscountPaise;
  final int commissionBasePaise;
  final int commissionBps;
  final int commissionPaise;
  final int commissionGstPaise;
  final int tdsPaise;

  /// What the restaurant is paid out.
  final int settlementPaise;

  final int packagingPaise;
  final int deliveryFeePaise;
  final int oxroDiscountPaise;
  final int tipPaise;
}

/// Full bill for a cart (possibly many restaurants).
class OrderQuote {
  const OrderQuote({
    required this.itemSubtotalPaise,
    required this.packagingPaise,
    required this.deliveryFeePaise,
    required this.platformFeePaise,
    required this.smallCartFeePaise,
    required this.taxPaise,
    required this.tipPaise,
    required this.discountPaise,
    required this.grandTotalPaise,
    required this.subOrders,
    required this.configVersion,
  });

  final int itemSubtotalPaise;
  final int packagingPaise;
  final int deliveryFeePaise;
  final int platformFeePaise;

  /// Customer small-cart fee: ₹20 below ₹50, ₹15 for ₹50–₹69.99,
  /// ₹10 for ₹70–₹98.99 and ₹0 from ₹99. Added to the grand total but
  /// kept separate from the delivery fee.
  final int smallCartFeePaise;

  final int taxPaise;
  final int tipPaise;
  final int discountPaise;
  final int grandTotalPaise;
  final List<SubOrderQuote> subOrders;
  final int configVersion;

  int get commissionPaise =>
      subOrders.fold(0, (s, o) => s + o.commissionPaise);

  int get commissionGstPaise =>
      subOrders.fold(0, (s, o) => s + o.commissionGstPaise);

  int get tdsPaise =>
      subOrders.fold(0, (s, o) => s + o.tdsPaise);

  int get sellerSettlementPaise =>
      subOrders.fold(0, (s, o) => s + o.settlementPaise);
}

/// Inputs to a delivery payout.
class DeliveryPayoutInput {
  const DeliveryPayoutInput({
    required this.roadMetres,
    this.orderCount = 1,
    this.tipPaise = 0,
    this.waitingMinutes = 0,
    this.penaltyPaise = 0,
    required this.acceptedAt,
  });

  final int roadMetres;
  final int orderCount;
  final int tipPaise;
  final int waitingMinutes;
  final int penaltyPaise;
  final DateTime acceptedAt;
}

/// Rider earnings for one trip.
class DeliveryPayout {
  const DeliveryPayout({
    required this.billableKm,
    required this.basePayoutPaise,
    required this.distancePayPaise,
    required this.stackingBonusPaise,
    required this.peakBonusPaise,
    required this.specialBonusPaise,
    required this.waitingCompPaise,
    required this.tipPaise,
    required this.penaltyPaise,
    required this.totalPaise,
    required this.configVersion,
  });

  final double billableKm;
  final int basePayoutPaise;
  final int distancePayPaise;
  final int stackingBonusPaise;
  final int peakBonusPaise;
  final int specialBonusPaise;
  final int waitingCompPaise;
  final int tipPaise;
  final int penaltyPaise;
  final int totalPaise;
  final int configVersion;
}

/// The OXRO pricing engine. Stateless: construct with a config and call.
class PricingEngine {
  const PricingEngine(this.config);

  final PricingConfig config;

  /// Distance is measured by the routing provider, then rounded **up** to
  /// the next 0.1 km so a rider is never underpaid. 2990 m -> 3.0 km.
  static double billableKmFor(int roadMetres) {
    final decimetres = Money.ceilDiv(roadMetres, 100);
    return decimetres / 10.0;
  }

  /// Subtotal (in paise) at which the small-cart fee is fully waived.
  static const int smallCartFeeWaiverThresholdPaise = 9900;

  /// Small-cart fee for the pre-coupon item subtotal (in paise).
  ///
  /// ₹20 below ₹50 · ₹15 for ₹50–₹69.99 · ₹10 for ₹70–₹98.99 ·
  /// ₹0 from ₹99. An empty cart is never charged.
  static int smallCartFeePaiseFor(int itemSubtotalPaise) {
    if (itemSubtotalPaise <= 0) return 0;
    if (itemSubtotalPaise < 5000) return 2000;
    if (itemSubtotalPaise < 7000) return 1500;
    if (itemSubtotalPaise < smallCartFeeWaiverThresholdPaise) return 1000;
    return 0;
  }

  /// Amount still needed (in paise) to remove the small-cart fee.
  /// Returns 0 for an empty cart or once the fee is already waived.
  static int smallCartFeeWaiverRemainingPaise(int itemSubtotalPaise) {
    if (itemSubtotalPaise <= 0 ||
        itemSubtotalPaise >= smallCartFeeWaiverThresholdPaise) {
      return 0;
    }
    return smallCartFeeWaiverThresholdPaise - itemSubtotalPaise;
  }

  OrderQuote quoteOrder(OrderQuoteInput input) {
    config.validate();

    final subQuotes = <SubOrderQuote>[];
    var itemSubtotal = 0;
    var packaging = 0;
    var delivery = 0;
    var tip = 0;
    var discount = 0;

    for (final s in input.subOrders) {
      final bps = s.commissionBpsOverride ?? config.commissionBps;
      final base =
          (s.foodSubtotalPaise - s.restaurantDiscountPaise)
              .clamp(0, 1 << 62);
      final commission = Money.applyBps(base, bps);
      final commissionGst =
          Money.applyBps(commission, config.commissionGstBps);
      final tds = Money.applyBps(base, config.tdsBps);
      final settlement =
          base - commission - commissionGst - tds;

      subQuotes.add(SubOrderQuote(
        restaurantId: s.restaurantId,
        foodSubtotalPaise: s.foodSubtotalPaise,
        restaurantDiscountPaise: s.restaurantDiscountPaise,
        commissionBasePaise: base,
        commissionBps: bps,
        commissionPaise: commission,
        commissionGstPaise: commissionGst,
        tdsPaise: tds,
        settlementPaise: settlement,
        packagingPaise: s.packagingPaise,
        deliveryFeePaise: s.deliveryFeePaise,
        oxroDiscountPaise: s.oxroDiscountPaise,
        tipPaise: s.tipPaise,
      ));

      itemSubtotal += s.foodSubtotalPaise;
      packaging += s.packagingPaise;
      delivery += s.deliveryFeePaise;
      tip += s.tipPaise;
      discount += s.restaurantDiscountPaise + s.oxroDiscountPaise;
    }

    final platformFee =
        input.platformFeeOverridePaise ?? config.platformFeePaise;
    final smallCartFee = smallCartFeePaiseFor(itemSubtotal);
    final tax = Money.applyBps(itemSubtotal, config.customerGstBps);
    final grandTotal =
        (itemSubtotal + packaging + delivery + platformFee +
                smallCartFee + tax +
                tip -
                discount)
            .clamp(0, 1 << 62);

    return OrderQuote(
      itemSubtotalPaise: itemSubtotal,
      packagingPaise: packaging,
      deliveryFeePaise: delivery,
      platformFeePaise: platformFee,
      smallCartFeePaise: smallCartFee,
      taxPaise: tax,
      tipPaise: tip,
      discountPaise: discount,
      grandTotalPaise: grandTotal,
      subOrders: subQuotes,
      configVersion: config.version,
    );
  }

  DeliveryPayout payoutFor(DeliveryPayoutInput input) {
    config.validate();

    final billable = billableKmFor(input.roadMetres);
    final billableDecimetres = Money.ceilDiv(input.roadMetres, 100);
    final includedDecimetres =
        Money.ceilDiv(config.includedDistanceMetres, 100);
    final extraDecimetres =
        (billableDecimetres - includedDecimetres).clamp(0, 1 << 62);

    // perKmPaise is per whole km; divide by 10 for each 0.1 km, rounding
    // half-up so a single extra 100 m never rounds to zero.
    final distancePay =
        Money.roundHalfUpDiv(extraDecimetres * config.perKmPaise, 10);

    final orders = input.orderCount < 1 ? 1 : input.orderCount;
    final stacking = (orders - 1) * config.stackingBonusPaise;

    var peak = 0;
    for (final w in config.peakWindows) {
      if (w.covers(input.acceptedAt)) peak += w.bonusPaise;
    }

    var special = 0;
    for (final s in config.specialIncentives) {
      if (s.matches(
          roadMetres: input.roadMetres, orderCount: orders)) {
        special += s.bonusPaise;
      }
    }

    final paidWait =
        (input.waitingMinutes - config.freeWaitingMinutes)
            .clamp(0, 1 << 62);
    final waiting = paidWait * config.waitingCompPerMinutePaise;

    final total = (config.basePayoutPaise +
            distancePay +
            stacking +
            peak +
            special +
            waiting +
            input.tipPaise -
            input.penaltyPaise)
        .clamp(0, 1 << 62);

    return DeliveryPayout(
      billableKm: billable,
      basePayoutPaise: config.basePayoutPaise,
      distancePayPaise: distancePay,
      stackingBonusPaise: stacking,
      peakBonusPaise: peak,
      specialBonusPaise: special,
      waitingCompPaise: waiting,
      tipPaise: input.tipPaise,
      penaltyPaise: input.penaltyPaise,
      totalPaise: total,
      configVersion: config.version,
    );
  }
}
